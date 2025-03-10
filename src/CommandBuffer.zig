const std = @import("std");
const Window = @import("Window.zig");
const c = Window.c;

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

pub fn acquireSwapchain(self: CommandBuffer, window: Window) ?*c.SDL_GPUTexture {
    var swapchain_texture: ?*c.SDL_GPUTexture = null;
    _ = c.SDL_AcquireGPUSwapchainTexture(self.handle, window.handle, &swapchain_texture, null, null);
    return swapchain_texture;
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
