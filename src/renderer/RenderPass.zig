const texture = @import("texture.zig");
const Buffer = @import("Buffer.zig");
const GraphicsPipeline = @import("GraphicsPipeline.zig");
const c = @import("solis").external.c;
const Self = @This();

pub const ColorTarget = struct {
    texture: texture.Handle,
    clear_color: [4]f32,
    load_op: u32 = c.SDL_GPU_LOADOP_CLEAR,
    store_op: u32 = c.SDL_GPU_STOREOP_STORE,
};

pub const DepthStencilTarget = struct {
    texture: texture.Handle,
    load_op: u32 = c.SDL_GPU_LOADOP_CLEAR,
    store_op: u32 = c.SDL_GPU_STOREOP_STORE,
    stencil_load_op: u32 = c.SDL_GPU_LOADOP_DONT_CARE,
    stencil_store_op: u32 = c.SDL_GPU_STOREOP_DONT_CARE,
    clear_depth: f32 = 1.0,
    cycle: bool = true,
};

handle: ?*c.SDL_GPURenderPass,

pub fn end(self: Self) void {
    c.SDL_EndGPURenderPass(self.handle);
}

pub fn bindGraphicsPipeline(self: Self, pipeline: GraphicsPipeline) void {
    c.SDL_BindGPUGraphicsPipeline(self.handle, pipeline.handle);
}

pub fn bindFragmentSamplers(self: Self, index: u32, samplers: []const c.SDL_GPUTextureSamplerBinding) void {
    c.SDL_BindGPUFragmentSamplers(self.handle, index, samplers.ptr, @intCast(samplers.len));
}

pub fn bindFragmentStorageBuffers(self: Self, index: u32, buffers: []const *c.SDL_GPUBuffer) void {
    c.SDL_BindGPUFragmentStorageBuffers(self.handle, index, buffers.ptr, @intCast(buffers.len));
}

pub fn bindVertexBuffers(self: Self, index: u32, bindings: []const c.SDL_GPUBufferBinding) void {
    c.SDL_BindGPUVertexBuffers(self.handle, index, bindings.ptr, @intCast(bindings.len));
}

pub fn bindIndexBuffers(self: Self, binding: *const c.SDL_GPUBufferBinding, element_size: u32) void {
    c.SDL_BindGPUIndexBuffer(self.handle, binding, element_size);
}

pub fn drawPrimitives(self: Self, numVertices: u32) void {
    c.SDL_DrawGPUPrimitives(self.handle, numVertices, 1, 0, 0);
}

pub fn drawPrimitivesIndexed(self: Self, numVertices: u32) void {
    c.SDL_DrawGPUIndexedPrimitives(self.handle, numVertices, 1, 0, 0, 1);
}
