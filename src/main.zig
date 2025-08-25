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
const system_event = solis.system_event;
const ShaderImporter = solis.render.ShaderImporter;
const MeshBuffer = solis.render.MeshBuffer;
const defaults = solis.defaults;
const input = solis.input;
const ecs = solis.ecs;
const World = solis.world.World;
const Query = solis.world.Query;
const Global = solis.world.Global;

const Events = solis.events.Events;
const EventReader = solis.events.EventReader;
const EventWriter = solis.events.EventWriter;

const SDL_ERROR = Window.SDL_ERROR;

fn cameraMover(key_input: Global(input.KeyboardInput), query: Query(.{Camera})) void {
    var iter = query.iter();
    while (iter.next()) |iter_val| {
        var camera = @field(iter_val, "0") orelse continue;
        if (key_input.get().isKeyPressed(c.SDL_SCANCODE_D)) {
            camera[0].position[0] -= 0.02;
        } else if (key_input.get().isKeyPressed(c.SDL_SCANCODE_A)) {
            camera[0].position[0] += 0.02;
        }
    }
}

fn handleWindowResized(window_events: EventReader(Window.Event), query: Query(.{ Texture, Window, Camera }), renderer: Global(Renderer)) void {
    var iter = query.iter();
    defer iter.deinit();

    var texture, const window, var camera = iter.next() orelse return;

    while (window_events.next()) |event| {
        renderer.getMut().releaseTexture(texture.?[0]);
        texture.?[0] = renderer.getMut().createTexture(.{
            .extent = .{ .width = @intCast(event.resized.width), .height = @intCast(event.resized.height) },
            .format = TextureFormat.depth16unorm,
            .usage = .depth_stencil_target,
            .label = "Depth Texture",
            .type = .image2d,
        }) catch @panic("Failed to create DepthTexture");
        camera.?[0].aspect = window.?[0].getAspect();
    }
}

pub fn main() !void {
    if (std.os.argv.len < 2) {
        std.log.err("Expected at least one argument", .{});
        return;
    }

    errdefer c.SDL_Log("Error: %s", c.SDL_GetError());
    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) return SDL_ERROR.Fail;
    defer c.SDL_Quit();

    const allocator = std.heap.page_allocator;
    const file_path: []const u8 = @ptrCast(std.os.argv[1][0..std.mem.len(std.os.argv[1])]);

    var world = World.init(allocator);
    defer world.deinit();

    // world.register(assets.Server);
    var asset_server = world.registerGlobal(assets.Server, assets.Server.init(std.heap.page_allocator));
    _ = world.registerGlobal(input.KeyboardInput, .init(allocator));

    try asset_server.register_importer(Image, assets.ImageImporter);
    try asset_server.register_importer(Shader, ShaderImporter);

    const parsed = try Gltf.parseFromFile(std.heap.page_allocator, file_path);
    const meshes = try parsed.parseMeshes(std.heap.page_allocator);
    defer meshes.deinit();

    if (meshes.items.len == 0) return error.NoMeshesFound;

    // Video subsystem & windows
    world.register(Window);
    world.register(Texture);
    world.register(Camera);
    const window_handle = world.newEntity("Main Window");
    var window = world.set(window_handle, Window, try Window.init());

    world.registerEvent(Window.Event);
    world.registerEvent(system_event.SystemEvent);
    world.registerEvent(input.InputEvent);
    try world.addSystem(system_event.handleSDLEvents, .{ .stage = ecs.PreUpdate });
    try world.addSystem(input.keyboardInputSystem, .{ .stage = ecs.PreUpdate });
    try world.addSystem(cameraMover, .{});

    var renderer = world.registerGlobal(Renderer, try Renderer.init(&world, window));
    try world.addSystem(handleWindowResized, .{});

    defaults.TextureDefaults.init(allocator, renderer) catch @panic("OOM");
    defer defaults.TextureDefaults.deinit(renderer);

    const pipeline = try renderer.createDefaultGraphicsPipeline(asset_server);
    defer renderer.destroyGraphicsPipeline(pipeline);

    // window textures
    _ = world.set(window_handle, Texture, try renderer.createTexture(.{
        .extent = .{ .width = @intCast(window.size[0]), .height = @intCast(window.size[1]) },
        .format = TextureFormat.depth16unorm,
        .usage = .depth_stencil_target,
        .type = .image2d,
        .label = "Depth Texture",
    }));
    defer renderer.releaseTexture(world.getMut(window_handle, Texture).*);

    // Buffers
    var buffers = std.ArrayList(MeshBuffer).init(allocator);
    for (meshes.items) |item| {
        try buffers.append(try MeshBuffer.init(renderer, item));
    }
    defer {
        for (buffers.items) |buffer| {
            buffer.deinit(renderer);
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
    defer environment_map.deinit(renderer);
    {
        const img = try asset_server.load(Image, "assets/textures/cubemap.jpg");
        defer asset_server.unload(Image, img);
        environment_map = try EnvironmentMap.initFromImage(renderer, asset_server.get(Image, img).?.*, allocator);
    }

    const sampler = try renderer.createSampler(.{});
    defer renderer.releaseSampler(sampler);

    // Materials
    var materials = try parsed.parseMaterials(allocator, textures.items);
    defer materials.deinit();

    if (materials.items.len == 0)
        try materials.append(Material{});

    // Camera
    const camera = world.set(window_handle, Camera, .{ .aspect = window.getAspect() });
    camera.position[2] = -2.5;

    var angle: f32 = 0;
    const reader_ent = world.newEntity("SystemEventReader");
    const system_events = try EventReader(system_event.SystemEvent).init(&world, reader_ent);

    // Main loop
    var done = false;
    while (!done) {
        world.update();
        while (system_events.next()) |sys_event| {
            if (sys_event.close_request) done = true;
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

        const color_target = RenderPass.ColorTarget{ .texture = swapchain_texture, .clear_color = .{ 0.1, 0.1, 0.1, 1.0 } };
        const depth_target = RenderPass.DepthStencilTarget{ .texture = world.getMut(window_handle, Texture).* };

        var pass = cmd.createRenderPass(color_target, depth_target) orelse @panic("Could not create RenderPass");
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
            buffer.bind(&pass, 0);

            const parsed_mesh = parsed.meshes.?[node.mesh.?];
            const mat_idx = parsed_mesh.primitives[0].material.?;
            const material_bindings = materials.items[mat_idx].createSamplerBinding(sampler);
            pass.bindFragmentSamplers(0, &material_bindings);
            pass.bindFragmentSamplers(material_bindings.len, &environment_map.createSamplerBinding(sampler));
            cmd.pushFragmentUniformData(0, u8, materials.items[mat_idx].createUniformBinding().toBuffer());

            if (buffer.index_buffer) |_| {
                pass.drawPrimitivesIndexed(buffer.element_count);
            } else {
                pass.drawPrimitives(buffer.element_count);
            }
        }

        pass.end();
    }
}
