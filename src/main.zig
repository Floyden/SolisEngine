const std = @import("std");
const solis = @import("solis");

const c = solis.external.c;
const Extent3d = solis.Extent3d;
const Window = solis.Window;
const Camera = solis.Camera;
const Light = solis.light.Light;
const Gltf = solis.Gltf;
const Material = solis.PBRMaterial;
const Image = solis.Image;
const assets = solis.assets;
const mesh = solis.mesh;
const matrix = solis.matrix;
const Vector3f = matrix.Vector3f;
const Vector4f = matrix.Vector4f;
const Matrix3f = matrix.Matrix3f;
const Matrix4f = matrix.Matrix4f;
const Buffer = solis.render.Buffer;
const RenderPass = solis.render.RenderPass;
const EnvironmentMap = solis.render.EnvironmentMap;
const Texture = solis.render.TextureHandle;
const TextureFormat = solis.render.TextureFormat;
const Renderer = solis.render.Renderer;
const Shader = solis.render.Shader;
const ShaderImporter = solis.render.ShaderImporter;
const defaults = solis.defaults;
const ecs = solis.ecs;
const World = solis.world.World;

const Events = solis.events.Events;
const EventReader = solis.events.EventReader;
const EventWriter = solis.events.EventWriter;

const SDL_ERROR = Window.SDL_ERROR;

const WindowResized = struct{ window: *Window, width: u32, height: u32 };
fn testFn(reader: EventReader(WindowResized), writer: EventWriter(WindowResized)) void {
    // const window: Window = undefined;
    // writer.emit(.{.window = &window, .width = 420, .height = 69});
    //
    std.log.debug("Reader: {?}", .{reader});
    std.log.debug("Writer: {?}", .{writer});
}

pub fn main() !void {
    if (std.os.argv.len < 2) {
        std.log.err("Expected at least one argument", .{});
        return;
    }
    const allocator = std.heap.page_allocator;
    const file_path: []const u8 = @ptrCast(std.os.argv[1][0..std.mem.len(std.os.argv[1])]);

    var world = World.init(allocator);
    defer world.deinit();

    world.register(assets.Server);
    var asset_server = world.setSingleton(assets.Server, assets.Server.init(std.heap.page_allocator));

    try asset_server.register_importer(Image, assets.ImageImporter);
    try asset_server.register_importer(Shader, ShaderImporter);

    const parsed = try Gltf.parseFromFile(std.heap.page_allocator, file_path);
    const meshes = try parsed.parseMeshes(std.heap.page_allocator);
    defer meshes.deinit();

    if (meshes.items.len == 0) return error.NoMeshesFound;

    errdefer c.SDL_Log("Error: %s", c.SDL_GetError());
    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) return SDL_ERROR.Fail;
    defer c.SDL_Quit();

    // Video subsystem & windows
    world.register(Window);
    const window_handle = world.newEntity("Main Window");
    var window = world.set(window_handle, Window, try Window.init());

    world.registerEvent(WindowResized);
    _ = world.getSingletonMut(Events(WindowResized)).?;
    var window_event_reader = world.getEventReader(WindowResized).?;
    var window_event_writer = world.getEventWriter(WindowResized).?;
    try world.addSystem(testFn);

    var renderer = try Renderer.init(window);
    defer renderer.deinit();
    defaults.TextureDefaults.init(allocator, &renderer) catch @panic("OOM");
    defer defaults.TextureDefaults.deinit(&renderer);

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
        .usage = .depth_stencil_target,
        .type = .image2d,
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
    try lights.append(Light.createPoint(Vector3f.create(.{ 0.0, 5.0, 0.0 }), Vector4f.create(.{ 1.0, 1.0, 1.0, 1.0 }), 40));
    try lights.append(Light.createDirectional(Vector3f.create(.{ 1.0, 0.0, 2.0 }).normalize(), Vector4f.create(.{ 1.0, 1.0, 1.0, 1.0 }), 0.5));

    const lights_buffer = try renderer.createBufferNamed(@intCast(lights.items.len * @sizeOf(Light)), c.SDL_GPU_BUFFERUSAGE_GRAPHICS_STORAGE_READ, "Lights");
    defer renderer.releaseBuffer(lights_buffer);

    for (lights.items, 0..) |light, i|
        try renderer.uploadDataToBuffer(@intCast(i * @sizeOf(Light)), lights_buffer, light.toBuffer());

    // Image Texture
    var textures = std.ArrayList(Texture).init(allocator);
    defer {
        for (textures.items) |texture| renderer.releaseTexture(texture);
        textures.deinit();
    }
    if (parsed.images) |parsed_images| {
        for (0..parsed_images.len) |i| {
            const img = try parsed.loadImage(i, asset_server);
            defer asset_server.unload(Image, img);

            try textures.append(try renderer.createTextureFromImage(asset_server.get(Image, img).?.*));
        }
    }

    var environment_map: EnvironmentMap = undefined;
    defer environment_map.deinit(&renderer);
    {
        const img = try asset_server.load(Image, "assets/textures/cubemap.jpg");
        defer asset_server.unload(Image, img);
        environment_map = try EnvironmentMap.initFromImage(&renderer, asset_server.get(Image, img).?.*, allocator);
    }

    const sampler = try renderer.createSampler(.{});
    defer renderer.releaseSampler(sampler);

    // Materials
    var materials = try parsed.parseMaterials(allocator, textures.items);
    defer materials.deinit();

    if (materials.items.len == 0)
        try materials.append(Material{});

    // Camera
    var camera = Camera{ .aspect = window.getAspect() };
    camera.position[2] = -2.5;

    var angle: f32 = 0;
    // Main loop
    var done = false;
    var event: c.SDL_Event = undefined;
    world.update();
    while (!done) {
        window.update();
        while (c.SDL_PollEvent(&event) and !done) {
            switch (event.type) {
                c.SDL_EVENT_QUIT, c.SDL_EVENT_WINDOW_CLOSE_REQUESTED => done = true,
                c.SDL_EVENT_WINDOW_RESIZED => try window_event_writer.emit(.{.window = window, .width = @intCast(event.window.data1), .height = @intCast(event.window.data2) }),
                else => {},
            }
        }
        c.SDL_Delay(16);
        lights.items[1].direction = Vector4f.create(.{ @sin(angle), 0.0, @cos(angle), 0.0 });
        angle += 0.03;
        try renderer.uploadDataToBuffer(@intCast(@sizeOf(Light)), lights_buffer, lights.items[1].toBuffer());

        const cmd = try renderer.acquireCommandBuffer();
        defer cmd.submit();

        const swapchain_texture = cmd.acquireSwapchain(window) orelse {
            cmd.cancel();
            continue;
        };

        while (window_event_reader.next()) |resize| {
            renderer.releaseTexture(tex_depth);
            tex_depth = try renderer.createTexture(.{
                .extent = .{ .width = resize.width, .height = resize.height },
                .format = TextureFormat.depth16unorm,
                .usage = .depth_stencil_target,
                .label = "Depth Texture",
                .type = .image2d,
            });
            camera.aspect = window.getAspect();
        }

        const color_target = RenderPass.ColorTarget{ .texture = swapchain_texture, .clear_color = .{ 0.1, 0.1, 0.1, 1.0 } };
        const depth_target = RenderPass.DepthStencilTarget{ .texture = tex_depth };

        const pass = cmd.createRenderPass(color_target, depth_target) orelse @panic("Could not create RenderPass");
        pass.bindGraphicsPipeline(pipeline);
        pass.bindFragmentStorageBuffers(0, &.{lights_buffer.handle});

        for (parsed.nodes.?) |node| {
            var transform = node.getTransform();
            const model_matrix = transform.toMatrix();
            // MVP, model, MV
            var matrices = [_]matrix.Matrix4f{ model_matrix, model_matrix, undefined };
            matrices[2] = camera.viewMatrix().mult(matrices[0]);
            matrices[0] = camera.projectionMatrix().mult(matrices[2]);

            for (&matrices) |*mat|
                mat.* = mat.transpose();

            cmd.pushVertexUniformData(0, Matrix4f, &matrices);

            const buffer = buffers.items[node.mesh.?];
            const vertex_binding = c.SDL_GPUBufferBinding{ .buffer = buffer.vertex_buffer.handle, .offset = 0 };
            pass.bindVertexBuffers(0, &.{vertex_binding});

            const parsed_mesh = parsed.meshes.?[node.mesh.?];
            const mat_idx = parsed_mesh.primitives[0].material.?;
            const material_bindings = materials.items[mat_idx].createSamplerBinding(sampler);
            pass.bindFragmentSamplers(0, &material_bindings);
            pass.bindFragmentSamplers(material_bindings.len, &environment_map.createSamplerBinding(sampler));
            cmd.pushFragmentUniformData(0, u8, materials.items[mat_idx].createUniformBinding().toBuffer());

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
