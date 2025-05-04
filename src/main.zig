const std = @import("std");
const zigimg = @import("zigimg");

pub const external = @import("external.zig");
const c = external.c;
pub const Extent3d = @import("Extent3d.zig");
pub const Window = @import("Window.zig");
const Camera = @import("Camera.zig");
const Renderer = @import("Renderer.zig");
const Light = @import("light.zig").Light;
const Gltf = @import("Gltf.zig");
const Material = @import("PBRMaterial.zig");
pub const type_id = @import("type_id.zig");
pub const uuid = @import("uuid.zig");
pub const Image = @import("Image.zig");
pub const assets = @import("assets.zig");
pub const mesh = @import("mesh.zig");
pub const matrix = @import("matrix.zig");
const Vector3f = matrix.Vector3f;
const Vector4f = matrix.Vector4f;
const TextureFormat = @import("renderer/texture.zig").Format;
const Texture = @import("renderer/texture.zig").Handle;
const RenderPass = @import("renderer/RenderPass.zig");
const Buffer = @import("renderer/Buffer.zig");
const Shader = @import("renderer/Shader.zig");
const ShaderImporter = @import("renderer/ShaderImporter.zig");
const defaults = @import("defaults.zig");

const CommandBuffer = @import("renderer/CommandBuffer.zig");
const SDL_ERROR = Window.SDL_ERROR;

pub fn main() !void {
    if (std.os.argv.len < 2) {
        std.log.err("Expected at least one argument", .{});
        return;
    }

    var asset_server = assets.Server.init(std.heap.page_allocator);
    defer asset_server.deinit();
    try asset_server.register_importer(Image, assets.ImageImporter);
    try asset_server.register_importer(Shader, ShaderImporter);

    const allocator = std.heap.page_allocator;
    const file_path: []const u8 = @ptrCast(std.os.argv[1][0..std.mem.len(std.os.argv[1])]);

    const parsed = try Gltf.parseFromFile(std.heap.page_allocator, file_path);
    const meshes = try parsed.parseMeshes(std.heap.page_allocator);
    defer meshes.deinit();

    if (meshes.items.len == 0) return error.NoMeshesFound;

    errdefer c.SDL_Log("Error: %s", c.SDL_GetError());
    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) return SDL_ERROR.Fail;
    defer c.SDL_Quit();

    // Video subsystem & windows
    var window = Window.init() catch |e| return e;
    defer window.deinit();

    var renderer = Renderer.init(&window) catch |e| return e;
    defer renderer.deinit();
    defaults.texture_defaults = defaults.TextureDefaults.init(allocator, &renderer) catch @panic("OOM");
    defer defaults.texture_defaults.?.deinit(&renderer);

    const vs_handle = try asset_server.load(Shader, "./assets/shaders/default.vert");
    defer asset_server.unload(Shader, vs_handle);
    const fs_handle = try asset_server.load(Shader, "./assets/shaders/default.frag");
    defer asset_server.unload(Shader, fs_handle);

    const pipeline = try renderer.createGraphicsPipeline(.{
        .vertex_shader = asset_server.get(Shader, vs_handle).?.*,
        .fragment_shader = asset_server.get(Shader, fs_handle).?.*,
    });
    defer renderer.destroyGraphicsPipeline(pipeline);

    // window textures
    var tex_depth = try renderer.createTexture(.{
        .extent = .{ .width = @intCast(window.size[0]), .height = @intCast(window.size[1]) },
        .format = TextureFormat.depth16unorm,
        .usage = c.SDL_GPU_TEXTUREUSAGE_DEPTH_STENCIL_TARGET,
        .label = "Depth Texture",
    });
    defer renderer.releaseTexture(tex_depth);

    // Buffers
    const BufferPair = struct { vertex_buffer: Buffer, index_buffer: ?Buffer };
    var buffers = std.ArrayList(BufferPair).init(allocator);
    for (meshes.items) |item| {
        const vertex_buffer = try renderer.createBufferFromData(item.data.?, c.SDL_GPU_BUFFERUSAGE_VERTEX, "Vertex Buffer");
        const index_buffer = if (item.index_buffer) |buf| try renderer.createBufferFromData(buf.rawBytes(), c.SDL_GPU_BUFFERUSAGE_INDEX, "Index Buffer") else null;
        try buffers.append(.{ .vertex_buffer = vertex_buffer, .index_buffer = index_buffer });
    }
    defer {
        for (buffers.items) |buffer| {
            renderer.releaseBuffer(buffer.vertex_buffer);
            if (buffer.index_buffer) |idx|
                renderer.releaseBuffer(idx);
        }
        buffers.deinit();
    }

    // Lights
    var lights = std.ArrayList(Light).init(allocator);
    defer lights.deinit();
    try lights.append(Light.createPoint(Vector3f.from(&[_]f32{ 5.0, 0.0, 2.0 }), Vector4f.from(&[_]f32{ 1.0, 1.0, 1.0, 1.0 }), 40));
    try lights.append(Light.createDirectional(Vector3f.from(&[_]f32{ -1.0, 0.0, 2.0 }).normalize(), Vector4f.from(&[_]f32{ 1.0, 0.0, 0.0, 1.0 }), 80));

    const lights_buffer = try renderer.createBufferNamed(@intCast(lights.items.len * @sizeOf(Light)), c.SDL_GPU_BUFFERUSAGE_GRAPHICS_STORAGE_READ, "Lights");
    defer renderer.releaseBuffer(lights_buffer);

    for (lights.items, 0..) |light, i|
        try renderer.uploadDataToBuffer(@intCast(i * @sizeOf(Light)), lights_buffer, light.toBuffer());

    // Image Texture
    const images = [_]?assets.Handle(Image){
        try parsed.loadBaseColorImage(&asset_server),
        try parsed.loadMetalRoughImage(&asset_server),
        try parsed.loadNormalImage(&asset_server),
    };
    defer for (images) |image_opt| if (image_opt) |image| asset_server.unload(Image, image);

    var textures: [3]?Texture = undefined;
    for (0..3) |i|
        textures[i] = if (images[i]) |image| try renderer.createTextureFromImage(asset_server.get(Image, image).?.*) else null;
    defer for (textures) |texture_opt| if (texture_opt) |texture| renderer.releaseTexture(texture);

    const sampler = try renderer.createSampler(.{});
    defer renderer.releaseSampler(sampler);

    const material = Material{
        .base_color = .{ 1.0, 1.0, 1.0, 1.0 },
        .base_color_texture = textures[0],
        .metallic = 0.0,
        .metallic_texture = textures[1],
        .normal_texture = textures[2],
    };
    const binding = material.createUniformBinding();

    var camera = Camera{ .aspect = window.getAspect() };
    camera.position[2] = -2.5;

    // Main loop
    var done = false;
    var event: c.SDL_Event = undefined;
    while (!done) {
        window.update();
        while (c.SDL_PollEvent(&event) and !done) {
            switch (event.type) {
                c.SDL_EVENT_QUIT, c.SDL_EVENT_WINDOW_CLOSE_REQUESTED => done = true,
                else => {},
            }
        }
        c.SDL_Delay(16);
        const cmd = renderer.acquireCommandBuffer() orelse return SDL_ERROR.Fail;
        defer cmd.submit();

        const swapchain_texture = cmd.acquireSwapchain(window) orelse {
            cmd.cancel();
            continue;
        };

        if (window.has_resized) {
            renderer.releaseTexture(tex_depth);
            tex_depth = try renderer.createTexture(.{
                .extent = .{ .width = @intCast(window.size[0]), .height = @intCast(window.size[1]) },
                .format = TextureFormat.depth16unorm,
                .usage = c.SDL_GPU_TEXTUREUSAGE_DEPTH_STENCIL_TARGET,
                .label = "Depth Texture",
            });
            camera.aspect = window.getAspect();
        }

        const color_target = RenderPass.ColorTarget{ .texture = swapchain_texture, .clear_color = .{ 0.1, 0.1, 0.1, 1.0 } };
        const depth_target = RenderPass.DepthStencilTarget{ .texture = tex_depth };

        const pass = cmd.createRenderPass(color_target, depth_target) orelse @panic("Could not create RenderPass");
        pass.bindGraphicsPipeline(pipeline);

        const sampler_binding = material.createSamplerBinding(sampler.id);
        pass.bindFragmentSamplers(0, &sampler_binding);
        pass.bindFragmentStorageBuffers(0, &.{lights_buffer.handle});
        cmd.pushFragmentUniformData(0, u8, binding.toBuffer());

        for (parsed.nodes.?) |node| {
            var transform = node.getTransform();
            const model_matrix = transform.toMatrix();
            var matrices = .{ model_matrix, model_matrix };
            matrices[0] = matrices[0].mult(camera.viewMatrix());
            matrices[0] = matrices[0].mult(camera.projectionMatrix());

            cmd.pushVertexUniformData(0, f32, @as(*[32]f32, @ptrCast(&matrices)));

            const buffer = buffers.items[node.mesh.?];
            const vertex_binding = c.SDL_GPUBufferBinding{ .buffer = buffer.vertex_buffer.handle, .offset = 0 };
            pass.bindVertexBuffers(0, &.{vertex_binding});

            if (buffer.index_buffer) |index| {
                const index_binding = c.SDL_GPUBufferBinding{ .buffer = index.handle, .offset = 0 };
                pass.bindIndexBuffers(&index_binding, meshes.items[0].index_buffer.?.elementType());
                pass.drawPrimitivesIndexed(meshes.items[0].index_buffer.?.size());
            } else {
                pass.drawPrimitives(meshes.items[0].num_vertices);
            }
        }

        pass.end();
    }
}
