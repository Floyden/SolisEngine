const std = @import("std");
const Window = @import("Window.zig");
const Renderer = @import("Renderer.zig");
const matrix = @import("matrix.zig");
const light = @import("light.zig");
const Gltf = @import("Gltf.zig");
const c = Renderer.c;
const CommandBuffer = Renderer.CommandBuffer;
const SDL_ERROR = Window.SDL_ERROR;

pub fn main() !void {
    if (std.os.argv.len < 2) {
        std.log.err("Expected at least one argument", .{});
        return;
    }

    const file_path: []const u8 = @ptrCast(std.os.argv[1][0..std.mem.len(std.os.argv[1])]);

    const parsed = Gltf.parseFromFile(std.heap.page_allocator, file_path) catch @panic("Failed");
    const mesh = parsed.parseMeshData(0, std.heap.page_allocator) catch @panic("Mesh Failed");
    var base_image = try parsed.loadImageFromFile(0, std.heap.page_allocator);
    defer base_image.deinit();

    errdefer c.SDL_Log("Error: %s", c.SDL_GetError());
    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) return SDL_ERROR.Fail;
    defer c.SDL_Quit();

    // Video subsystem & windows
    var window = Window.init() catch |e| return e;
    defer window.deinit();

    var renderer = Renderer.init(&window) catch |e| return e;
    defer renderer.deinit();

    // window textures

    var tex_depth = try renderer.createTexture(.{
        .width = @intCast(window.size[0]),
        .height = @intCast(window.size[1]),
        .depth = 1,
        .format = Renderer.PixelFormat.grayscale16,
        .usage = c.SDL_GPU_TEXTUREUSAGE_DEPTH_STENCIL_TARGET,
        .label = "Depth Texture",
    });
    defer c.SDL_ReleaseGPUTexture(renderer.device, tex_depth);

    // Buffers
    // const current_vert: []const u8 = @ptrCast(&c.quad_data);
    const current_vert: []const u8 = mesh.data.?;
    const buf_vertex = renderer.createBufferNamed(@intCast(current_vert.len), c.SDL_GPU_BUFFERUSAGE_VERTEX, "Vertex Buffer") catch |e| return e;
    defer renderer.releaseBuffer(buf_vertex);

    // Transfer data
    {
        const buf_transfer = renderer.createTransferBufferNamed(@intCast(current_vert.len), c.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD, "Transfer Buffer") catch |e| return e;
        defer renderer.releaseTransferBuffer(buf_transfer);

        renderer.copyToTransferBuffer(buf_transfer, @ptrCast(current_vert));

        var cmd = renderer.acquireCommandBuffer() orelse return SDL_ERROR.Fail;
        defer cmd.submit();

        cmd.beginCopyPass();
        cmd.uploadToBuffer(buf_transfer, buf_vertex, @intCast(current_vert.len));
        cmd.endCopyPass();
    }

    // Image Texture
    const texture = try renderer.createTexture(.{
        .width = @intCast(base_image.width),
        .height = @intCast(base_image.height),
        .depth = 1,
        .format = base_image.pixelFormat(),
        .usage = c.SDL_GPU_TEXTUREUSAGE_SAMPLER,
        .label = "Base Image",
    });
    defer c.SDL_ReleaseGPUTexture(renderer.device, texture);

    // Transfer image data
    {
        const buf_transfer = renderer.createTransferBufferNamed(@intCast(base_image.imageByteSize()), c.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD, "TexTransferBuffer") catch |e| return e;
        defer renderer.releaseTransferBuffer(buf_transfer);

        renderer.copyToTransferBuffer(buf_transfer, @ptrCast(base_image.rawBytes()));

        var cmd = renderer.acquireCommandBuffer() orelse return SDL_ERROR.Fail;
        defer cmd.submit();

        cmd.beginCopyPass();
        const source = c.SDL_GPUTextureTransferInfo{
            .transfer_buffer = buf_transfer,
            .offset = 0,
            .pixels_per_row = @intCast(base_image.width),
            .rows_per_layer = @intCast(base_image.height),
        };
        const destination = std.mem.zeroInit(c.SDL_GPUTextureRegion, .{
            .texture = texture,
            .w = @as(u32,@intCast(base_image.width)),
            .h = @as(u32,@intCast(base_image.height)),
            .d = 1,
        });

        c.SDL_UploadToGPUTexture(cmd.copy_pass, &source, &destination, true);

        cmd.endCopyPass();
    }

    const sampler = try renderer.createSampler(.{
        .address_mode_u = c.SDL_GPU_SAMPLERADDRESSMODE_REPEAT,
        .address_mode_v = c.SDL_GPU_SAMPLERADDRESSMODE_REPEAT,
        .address_mode_w = c.SDL_GPU_SAMPLERADDRESSMODE_REPEAT,
    });
    defer c.SDL_ReleaseGPUSampler(renderer.device, sampler);

    // Main loop
    var angle: f32 = 0.0;
    const point_light = light.PointLight{
        .position = .{ 5.0, 0.0, 0.0, 1.0 },
        .color = .{ 0.5, 0.5, 0.5, 1.0 },
        .intensity = 40.0,
    };

    var done = false;
    var event: c.SDL_Event = undefined;
    while (!done) {
        while (c.SDL_PollEvent(&event) and !done) {
            switch (event.type) {
                c.SDL_EVENT_QUIT, c.SDL_EVENT_WINDOW_CLOSE_REQUESTED => done = true,
                else => {},
            }
        }
        c.SDL_Delay(16);
        const cmd = renderer.acquireCommandBuffer() orelse return SDL_ERROR.Fail;
        defer cmd.submit();

        const swapchainTexture = cmd.acquireSwapchain(window) orelse {
            cmd.cancel();
            continue;
        };

        var current_window_size: @Vector(2, c_int) = .{ 0, 0 };
        _ = c.SDL_GetWindowSizeInPixels(window.handle, &current_window_size[0], &current_window_size[1]);
        if (@reduce(.Or, window.size != current_window_size)) {
            window.size = current_window_size;
            c.SDL_ReleaseGPUTexture(renderer.device, tex_depth);
            tex_depth = try renderer.createTexture(.{
                .width = @intCast(window.size[0]),
                .height = @intCast(window.size[1]),
                .depth = 1,
                .format = Renderer.PixelFormat.grayscale16,
                .usage = c.SDL_GPU_TEXTUREUSAGE_DEPTH_STENCIL_TARGET,
                .label = "Depth Texture",
            });
        }

        angle += 1;
        var matrices = .{ matrix.Matrix4f.diagonal_init(0.5), matrix.Matrix4f.rotation(.{ 1.0, 2.0, 0 }, angle) };
        matrices[0].atMut(3, 3).* = 1.0;
        matrices[0] = matrices[0].mult(matrix.Matrix4f.rotation(.{ 1.0, 2.0, 0 }, angle));
        matrices[1].data[14] -= 2.5;

        const canvas_size: @Vector(2, f32) = @floatFromInt(current_window_size);
        matrices[1] = matrices[1].mult(matrix.perspective(45.0, canvas_size[0] / canvas_size[1], 0.01, 100));

        var color_target = std.mem.zeroInit(c.SDL_GPUColorTargetInfo, .{
            .texture = swapchainTexture,
            .clear_color = .{ .r = 0.1, .g = 0.1, .b = 0.1, .a = 1.0 },
            .load_op = c.SDL_GPU_LOADOP_CLEAR,
            .store_op = c.SDL_GPU_STOREOP_STORE,
        });
        var depth_target = std.mem.zeroInit(c.SDL_GPUDepthStencilTargetInfo, .{
            .clear_depth = 1.0,
            .load_op = c.SDL_GPU_LOADOP_CLEAR,
            .store_op = c.SDL_GPU_STOREOP_DONT_CARE,
            .stencil_load_op = c.SDL_GPU_LOADOP_DONT_CARE,
            .stencil_store_op = c.SDL_GPU_STOREOP_DONT_CARE,
            .texture = tex_depth,
            .cycle = true,
        });


        const sampler_binding = c.SDL_GPUTextureSamplerBinding {
            .sampler = sampler,
            .texture = texture
        };

        const vertex_binding = c.SDL_GPUBufferBinding{ .buffer = buf_vertex, .offset = 0 };
        cmd.pushVertexUniformData(0, f32, @as(*[32]f32, @ptrCast(&matrices)));
        cmd.pushFragmentUniformData(0, f32, point_light.toBuffer());
        const pass = c.SDL_BeginGPURenderPass(cmd.handle, &color_target, 1, &depth_target);
        c.SDL_BindGPUGraphicsPipeline(pass, renderer.pipeline);
        c.SDL_BindGPUFragmentSamplers(pass, 0, &sampler_binding, 1);
        c.SDL_BindGPUVertexBuffers(pass, 0, &vertex_binding, 1);
        c.SDL_DrawGPUPrimitives(pass, 36, 1, 0, 0);
        c.SDL_EndGPURenderPass(pass);
    }
}
