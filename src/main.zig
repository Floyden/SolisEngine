const std = @import("std");
const c = @cImport({
    @cInclude("SDL3/SDL.h");
});

pub const SDL_ERROR = error{Fail};

pub fn main() SDL_ERROR!void {
    errdefer std.log.err("{s}", .{c.SDL_GetError()});

    if (!c.SDL_Init(c.SDL_INIT_VIDEO))
        return SDL_ERROR.Fail;

    defer c.SDL_Quit();

    const window = c.SDL_CreateWindow("Hey", 800, 600, c.SDL_WINDOW_VULKAN) orelse return SDL_ERROR.Fail;
    defer c.SDL_DestroyWindow(window);

    const device = c.SDL_CreateGPUDevice(c.SDL_GPU_SHADERFORMAT_SPIRV, true, null) orelse return SDL_ERROR.Fail;
    defer c.SDL_DestroyGPUDevice(device);

    if (!c.SDL_ClaimWindowForGPUDevice(device, window)) return SDL_ERROR.Fail;

    var event: c.SDL_Event = undefined;
    while (true) {
        if (c.SDL_PollEvent(&event) and (event.type == c.SDL_EVENT_QUIT or event.type == c.SDL_EVENT_WINDOW_CLOSE_REQUESTED))
            break;

        const cmd = c.SDL_AcquireGPUCommandBuffer(device) orelse return SDL_ERROR.Fail;
        var swapchainTexture: ?*c.SDL_GPUTexture = null;
        if (!c.SDL_AcquireGPUSwapchainTexture(cmd, window, &swapchainTexture, null, null)) return SDL_ERROR.Fail;

        if (swapchainTexture) |_| {
            var colorTarget = std.mem.zeroInit(c.SDL_GPUColorTargetInfo, .{
                .texture = swapchainTexture,
                .clear_color = .{ .r = 0, .g = 0, .b = 1.0, .a = 1.0 },
                .load_op = c.SDL_GPU_LOADOP_CLEAR,
                .store_op = c.SDL_GPU_STOREOP_STORE,
            });
            const renderPass = c.SDL_BeginGPURenderPass(cmd, &colorTarget, 1, null);
            c.SDL_EndGPURenderPass(renderPass);
        }

        _ = c.SDL_SubmitGPUCommandBuffer(cmd);
    }
}
