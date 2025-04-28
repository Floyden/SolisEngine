const std = @import("std");
const c = @import("solis").external.c;
const Window = @import("solis").Window;

const texture = @import("texture.zig");
const RenderPass = @import("RenderPass.zig");

const CommandBuffer = @This();
handle: *c.SDL_GPUCommandBuffer,
copy_pass: ?*c.SDL_GPUCopyPass = null,

pub fn submit(self: CommandBuffer) void {
    _ = c.SDL_SubmitGPUCommandBuffer(self.handle);
}
pub fn cancel(self: CommandBuffer) void {
    _ = c.SDL_CancelGPUCommandBuffer(self.handle);
}

pub fn beginCopyPass(self: *CommandBuffer) void {
    self.copy_pass = c.SDL_BeginGPUCopyPass(self.handle);
}

pub fn acquireSwapchain(self: CommandBuffer, window: Window) ?texture.Handle {
    var swapchain_texture: ?*c.SDL_GPUTexture = null;
    _ = c.SDL_AcquireGPUSwapchainTexture(self.handle, window.handle, &swapchain_texture, null, null);
    return if (swapchain_texture) |handle| .{ .id = handle } else null;
}

pub fn endCopyPass(self: *CommandBuffer) void {
    c.SDL_EndGPUCopyPass(self.copy_pass);
    self.copy_pass = null;
}

pub fn pushVertexUniformData(self: CommandBuffer, location: u32, T: type, data: []const T) void {
    c.SDL_PushGPUVertexUniformData(self.handle, location, data.ptr, @intCast(@sizeOf(T) * data.len));
}

pub fn pushFragmentUniformData(self: CommandBuffer, location: u32, T: type, data: []const T) void {
    c.SDL_PushGPUFragmentUniformData(self.handle, location, data.ptr, @intCast(@sizeOf(T) * data.len));
}

pub fn uploadToBuffer(self: CommandBuffer, src: *c.SDL_GPUTransferBuffer, dst: *c.SDL_GPUBuffer, length: u32) void {
    const buf_location = std.mem.zeroInit(c.SDL_GPUTransferBufferLocation, .{ .transfer_buffer = src });
    const dst_region = std.mem.zeroInit(c.SDL_GPUBufferRegion, .{
        .buffer = dst,
        .size = length,
    });
    c.SDL_UploadToGPUBuffer(self.copy_pass, &buf_location, &dst_region, false);
}

pub fn createRenderPass(self: CommandBuffer, colorTarget: RenderPass.ColorTarget, depth_target: RenderPass.DepthStencilTarget) ?RenderPass {
    const color = colorTarget.clear_color;
    const sdl_color_target = std.mem.zeroInit(c.SDL_GPUColorTargetInfo, .{
        .texture = colorTarget.texture.id,
        .clear_color = .{ .r = color[0], .g = color[1], .b = color[2], .a = color[3] },
        .load_op = colorTarget.load_op,
        .store_op = colorTarget.store_op,
    });
    const sdl_depth_target = std.mem.zeroInit(c.SDL_GPUDepthStencilTargetInfo, .{
        .texture = depth_target.texture.id,
        .load_op = depth_target.load_op,
        .store_op = depth_target.store_op,
        .stencil_load_op = depth_target.stencil_load_op,
        .stencil_store_op = depth_target.stencil_store_op,
        .clear_depth = depth_target.clear_depth,
        .cycle = depth_target.cycle,
    });
    return if (c.SDL_BeginGPURenderPass(self.handle, &sdl_color_target, 1, &sdl_depth_target)) |handle| return RenderPass{ .handle = handle } else null;
}
