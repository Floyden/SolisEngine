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
const Transformation = solis.Transformation;
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

fn handleMouseInput(mouse_button: EventReader(input.MouseButtonEvent), mouse_motion: EventReader(input.MouseMotionEvent)) void {
    while (mouse_button.next()) |event| {
        std.log.debug("Mouse input {}", .{event});
    }

    while (mouse_motion.next()) |event| {
        std.log.debug("Mouse motion {}", .{event});
    }
}

var window_handle: u64 = 0;

pub fn initModule(allocator: std.mem.Allocator, world: *World) !void {
    _ = world.registerGlobal(std.mem.Allocator, std.heap.page_allocator).*;

    try assets.Server.initModule(allocator, world);
    var asset_server = world.getGlobalMut(assets.Server) orelse @panic("Failed to get AssetServer");
    try asset_server.register_importer(Image, assets.ImageImporter);

    world.registerEvent(system_event.SystemEvent);
    try input.initModule(allocator, world);

    // Video subsystem & windows
    try Window.initModule(allocator, world);
    world.register(Camera);
    world.register(Material);
    world.register(Transformation);
    world.register(Light);

    window_handle = world.newEntity("Main Window");
    const window = world.set(window_handle, Window, try Window.init());

    try solis.render.initModule(allocator, world);

    _ = world.registerGlobal(Renderer, try Renderer.init(world, window));
    try world.addSystem(allocator, handleWindowResized, .{});
}

pub fn main() !void {
    if (std.os.argv.len < 2) {
        std.log.err("Expected at least one argument", .{});
        return;
    }

    errdefer c.SDL_Log("Error: %s", c.SDL_GetError());
    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) return SDL_ERROR.Fail;
    defer c.SDL_Quit();

    var world = World.init();
    defer world.deinit();

    const allocator = std.heap.page_allocator;
    try initModule(allocator, &world);

    var asset_server = world.getGlobalMut(assets.Server) orelse @panic("Failed to get AssetServer");
    const file_path: []const u8 = @ptrCast(std.os.argv[1][0..std.mem.len(std.os.argv[1])]);
    const parsed = try Gltf.parseFromFile(allocator, file_path);

    try world.addSystem(allocator, handleMouseInput, .{});
    try world.addSystem(allocator, cameraMover, .{});

    var renderer = world.getGlobalMut(Renderer).?;
    var window = world.get(window_handle, Window);

    const pipeline = try renderer.createDefaultGraphicsPipeline(asset_server);
    defer renderer.destroyGraphicsPipeline(pipeline);

    defaults.TextureDefaults.init(allocator, renderer) catch @panic("OOM");
    defer defaults.TextureDefaults.deinit(renderer);

    // window textures
    _ = world.set(window_handle, Texture, try renderer.createDepthTexture(window.size));
    defer renderer.releaseTexture(world.getMut(window_handle, Texture).*);

    // Lights
    const lights_buffer = try renderer.createBufferNamed(@intCast(2 * @sizeOf(Light)), c.SDL_GPU_BUFFERUSAGE_GRAPHICS_STORAGE_READ, "Lights");
    defer renderer.releaseBuffer(lights_buffer);
    {
        const point_ent = world.newEntity("PointLight");
        _ = world.set(point_ent, Light, Light.createPoint(Vector3f.create(.{ 0.0, 5.0, 0.0 }), Vector4f.create(.{ 1.0, 1.0, 1.0, 1.0 }), 40));

        const directional_ent = world.newEntity("DirectionalLight");
        _ = world.set(directional_ent, Light, Light.createDirectional(Vector3f.create(.{ 1.0, 0.0, 2.0 }).normalize(), Vector4f.create(.{ 1.0, 1.0, 1.0, 1.0 }), 0.5));
    }

    // Image Texture
    var textures: std.ArrayList(Texture) = .empty;
    defer {
        for (textures.items) |texture| renderer.releaseTexture(texture);
        textures.deinit(allocator);
    }

    var environment_map: EnvironmentMap = undefined;
    defer environment_map.deinit(renderer);

    {
        {
            const img = try asset_server.load(Image, "assets/textures/cubemap.jpg");
            defer asset_server.unload(Image, img);
            environment_map = try EnvironmentMap.initFromImage(renderer, asset_server.get(Image, img).?.*, allocator);
        }
        if (parsed.images) |parsed_images| {
            for (0..parsed_images.len) |i| {
                const img_handle = parsed.loadImage(i, asset_server) catch @panic("Failed to load Image");
                defer asset_server.unload(Image, img_handle);
                const img = asset_server.get(Image, img_handle) orelse @panic("Failed to load Image Handle");

                try textures.append(allocator, try renderer.createTextureFromImage(img.*));
            }
        }

        // Materials
        var materials = try parsed.parseMaterials(allocator, textures.items);
        defer materials.deinit(allocator);

        try materials.append(allocator, Material{});

        // TODO: Prefabs seem to not work atm
        // var material_prefabs = std.ArrayList(u64).empty;
        //
        // for (materials.items) |material| {
        //     const prefab = world.prefab("Material");
        //     try material_prefabs.append(allocator, prefab);
        //     _ = world.set(prefab, Material, material);
        // }

        // Buffers
        var meshes = try parsed.parseMeshes(allocator);
        defer meshes.deinit(allocator);
        if (meshes.items.len == 0) return error.NoMeshesFound;

        for (parsed.nodes.?) |node| {
            const entity = world.newEntity("Node");
            const material = parsed.meshes.?[node.mesh.?].primitives[0].material.?;
            // world.pair(entity, ecs.IsA, material_prefabs.items[material]);
            _ = world.set(entity, MeshBuffer, try MeshBuffer.init(renderer, meshes.items[node.mesh.?]));
            _ = world.set(entity, Transformation, node.getTransform());
            _ = world.set(entity, Material, materials.items[material]);
        }
    }

    const sampler = try renderer.createSampler(.{});
    defer renderer.releaseSampler(sampler);

    // Camera
    const camera = world.set(window_handle, Camera, .{ .aspect = window.getAspect() });
    camera.position[2] = -2.5;

    var angle: f32 = 0;
    const reader_ent = world.newEntity("SystemEventReader");
    const system_events = try EventReader(system_event.SystemEvent).init(&world, reader_ent);

    // Main loop
    var done = false;
    while (!done) {
        try system_event.handleSystemEvents(allocator, &world);
        while (system_events.next()) |sys_event| {
            if (sys_event.close_request) done = true;
        }

        world.update();
        c.SDL_Delay(16);

        const cmd = try renderer.acquireCommandBuffer();
        defer cmd.submit();

        const lights_query = try Query(.{Light}).init(&world, 0);
        var light_iter = lights_query.iter();
        while (light_iter.next()) |items| {
            const lights = @field(items, "0") orelse continue;
            for (lights) |*light| {
                if (light.type != .Directional)
                    continue;
                light.direction = Vector4f.create(.{ @sin(angle), 0.0, @cos(angle), 0.0 });
                try renderer.uploadDataToBuffer(@intCast(@sizeOf(Light)), lights_buffer, light.toBuffer());
            }
        }
        angle += 0.03;

        const swapchain_texture = cmd.acquireSwapchain(window) orelse {
            cmd.cancel();
            continue;
        };

        const color_target = RenderPass.ColorTarget{ .texture = swapchain_texture, .clear_color = .{ 0.1, 0.1, 0.1, 1.0 } };
        const depth_target = RenderPass.DepthStencilTarget{ .texture = world.getMut(window_handle, Texture).* };

        var pass = cmd.createRenderPass(color_target, depth_target) orelse @panic("Could not create RenderPass");
        pass.bindGraphicsPipeline(pipeline);
        pass.bindFragmentStorageBuffers(0, &.{lights_buffer.handle});

        const query = try Query(.{ MeshBuffer, Material, Transformation }).init(&world, 0);
        var iter = query.iter();
        while (iter.next()) |item| {
            const bufs, const mats, const transforms = item;
            for (bufs.?, mats.?, transforms.?) |buffer, material, transform| {
                const model_matrix = transform.toMatrix();
                // MVP, model, MV
                var matrices = [_]matrix.Matrix4f{ model_matrix, model_matrix, undefined };
                matrices[2] = camera.viewMatrix().mult(matrices[0]);
                matrices[0] = camera.projectionMatrix().mult(matrices[2]);

                for (&matrices) |*mat|
                    mat.* = mat.transpose();

                cmd.pushVertexUniformData(0, Matrix4f, &matrices);

                buffer.bind(&pass, 0);

                const material_bindings = material.createSamplerBinding(sampler);
                pass.bindFragmentSamplers(0, &material_bindings);
                pass.bindFragmentSamplers(material_bindings.len, &environment_map.createSamplerBinding(sampler));
                cmd.pushFragmentUniformData(0, u8, material.createUniformBinding().toBuffer());

                if (buffer.index_buffer) |_| {
                    pass.drawPrimitivesIndexed(buffer.element_count);
                } else {
                    pass.drawPrimitives(buffer.element_count);
                }
            }
        }
        pass.end();
    }
}
