const std = @import("std");
const Window = @import("Window.zig");
const Renderer = @import("Renderer.zig");
const c = Renderer.c;
const CommandBuffer = Renderer.CommandBuffer;
const SDL_ERROR = Window.SDL_ERROR;

fn createDepthTexture(device: *c.SDL_GPUDevice, drawable: [2]i32, sample_count: anytype) ?*c.SDL_GPUTexture {
    const createinfo = c.SDL_GPUTextureCreateInfo{
        .type = c.SDL_GPU_TEXTURETYPE_2D,
        .format = c.SDL_GPU_TEXTUREFORMAT_D16_UNORM,
        .width = @intCast(drawable[0]),
        .height = @intCast(drawable[1]),
        .layer_count_or_depth = 1,
        .num_levels = 1,
        .sample_count = sample_count,
        .usage = c.SDL_GPU_TEXTUREUSAGE_DEPTH_STENCIL_TARGET,
        .props = 0,
    };

    return c.SDL_CreateGPUTexture(device, &createinfo);
}

pub fn main() !void {
    errdefer c.SDL_Log("Error: %s", c.SDL_GetError());
    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) return SDL_ERROR.Fail;
    defer c.SDL_Quit();

    // Video subsystem & windows
    var window = Window.init() catch |e| return e;
    defer window.deinit();

    var renderer = Renderer.init(&window) catch |e| return e;
    defer renderer.deinit();

    // window textures

    var tex_depth = createDepthTexture(renderer.device.?, window.size, renderer.sample_count);
    if (tex_depth == null) return SDL_ERROR.Fail;
    defer c.SDL_ReleaseGPUTexture(renderer.device, tex_depth);

    // Buffers
    const buf_vertex = renderer.createBufferNamed(c.triangle_data_size, c.SDL_GPU_BUFFERUSAGE_VERTEX, "VertexBuffer") catch |e| return e;
    defer renderer.releaseBuffer(buf_vertex);

    // Transfer data
    {
        const buf_transfer = renderer.createTransferBufferNamed(c.triangle_data_size, c.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD, "TransferBuffer") catch |e| return e;
        defer renderer.releaseTransferBuffer(buf_transfer);

        renderer.copyToTransferBuffer(buf_transfer, @ptrCast(&c.triangle_data));

        var cmd = renderer.acquireCommandBuffer() orelse return SDL_ERROR.Fail;
        defer cmd.submit();

        cmd.beginCopyPass();
        cmd.uploadToBuffer(buf_transfer, buf_vertex);
        cmd.endCopyPass();
    }

    // Main loop
    const matrix = [16]f32{
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0,
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
            tex_depth = createDepthTexture(renderer.device.?, window.size, renderer.sample_count);
            if (tex_depth == null) return SDL_ERROR.Fail;
        }

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

        const vertex_binding = c.SDL_GPUBufferBinding{ .buffer = buf_vertex, .offset = 0 };
        cmd.pushVertexUniformData(f32, &matrix);
        const pass = c.SDL_BeginGPURenderPass(cmd.handle, &color_target, 1, &depth_target);
        c.SDL_BindGPUGraphicsPipeline(pass, renderer.pipeline);
        c.SDL_BindGPUVertexBuffers(pass, 0, &vertex_binding, 1);
        c.SDL_DrawGPUPrimitives(pass, 3, 1, 0, 0);
        c.SDL_EndGPURenderPass(pass);
    }
}
