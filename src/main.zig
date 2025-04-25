pub const external = @import("external.zig");
pub const Extent3d = @import("Extent3d.zig");

const std = @import("std");
const Window = @import("Window.zig");
const Camera = @import("Camera.zig");
const Renderer = @import("Renderer.zig");
const matrix = @import("matrix.zig");
const light = @import("light.zig");
const Gltf = @import("Gltf.zig");
const Material = @import("PBRMaterial.zig");
const c = external.c;
const zigimg = @import("zigimg");
pub const type_id = @import("type_id.zig");
pub const uuid = @import("uuid.zig");
pub const Image = @import("Image.zig");
pub const assets = @import("assets.zig");
const TextureFormat = @import("renderer/texture.zig").Format;
const Texture = @import("renderer/texture.zig").Handle;
const RenderPass = @import("renderer/RenderPass.zig");
const Shader = @import("renderer/Shader.zig");
const ShaderImporter = @import("renderer/ShaderImporter.zig");
const defaults = @import("defaults.zig");

const CommandBuffer = @import("CommandBuffer.zig");
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
    const mesh = parsed.parseMeshData(0, std.heap.page_allocator) catch @panic("Mesh Failed");

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
    const current_vert: []const u8 = mesh.data.?;
    const buf_vertex = renderer.createBufferFromData(current_vert, c.SDL_GPU_BUFFERUSAGE_VERTEX, "Vertex Buffer") catch |e| return e;
    defer renderer.releaseBuffer(buf_vertex);

    const buf_index = if (mesh.index_buffer) |buf| try renderer.createBufferFromData(buf.rawBytes(), c.SDL_GPU_BUFFERUSAGE_INDEX, "Index Buffer") else null;
    defer if (buf_index) |buf| renderer.releaseBuffer(buf);

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
    // camera.position[2] = -1.5;

    // Main loop
    var angle: f32 = 0.0;
    const point_light = light.PointLight{
        .position = .{ 5.0, 0.0, 2.0, 1.0 },
        .color = .{ 0.5, 0.5, 0.5, 1.0 },
        .intensity = 80.0,
    };

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

        angle += 1;

        var model_matrix = matrix.Matrix4f.diagonal_init(1);
        model_matrix.atMut(3, 3).* = 1.0;
        // model_matrix = model_matrix.mult(matrix.Matrix4f.rotation(.{ 1.0, 2.0, 0 }, angle));
        // model_matrix = model_matrix.mult(matrix.Matrix4f.rotation(.{ 0.0, 1.0, 0.0 }, 180));
        model_matrix.atMut(2, 3).* = -2.5;

        var matrices = .{ model_matrix, model_matrix };
        matrices[0] = matrices[0].mult(camera.viewMatrix());
        matrices[0] = matrices[0].mult(camera.projectionMatrix());

        const color_target = RenderPass.ColorTarget{ .texture = swapchain_texture, .clear_color = .{ 0.1, 0.1, 0.1, 1.0 } };
        const depth_target = RenderPass.DepthStencilTarget{ .texture = tex_depth };

        const sampler_binding = material.createSamplerBinding(sampler.id);

        cmd.pushVertexUniformData(0, f32, @as(*[32]f32, @ptrCast(&matrices)));
        cmd.pushFragmentUniformData(0, u8, binding.toBuffer());
        cmd.pushFragmentUniformData(1, f32, point_light.toBuffer());

        const pass = cmd.createRenderPass(color_target, depth_target) orelse @panic("Could not create RenderPass");
        pass.bindGraphicsPipeline(pipeline);
        pass.bindFragmentSamplers(0, &sampler_binding);

        const vertex_binding = c.SDL_GPUBufferBinding{ .buffer = buf_vertex, .offset = 0 };
        pass.bindVertexBuffers(0, &.{vertex_binding});

        if (buf_index) |index| {
            const index_binding = c.SDL_GPUBufferBinding{ .buffer = index, .offset = 0 };
            pass.bindIndexBuffers(&index_binding, mesh.index_buffer.?.elementType());
            pass.drawPrimitivesIndexed(mesh.index_buffer.?.size());
        } else {
            pass.drawPrimitives(mesh.num_vertices);
        }

        pass.end();
    }
}
