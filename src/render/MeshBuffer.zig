const Buffer = @import("Buffer.zig");
const Renderer = @import("Renderer.zig");
const RenderPass = @import("RenderPass.zig");
const solis = @import("solis");
const c = solis.external.c;
const Mesh = solis.mesh.Mesh;

vertex_buffer: Buffer,
element_count: u32,
index_buffer: ?Buffer,
index_element_type: u32,


const Self = @This();

pub fn init(renderer: *Renderer, mesh: Mesh) !Self {
    const vertex_buffer = try renderer.createBufferFromData(mesh.data.?, c.SDL_GPU_BUFFERUSAGE_VERTEX, "Vertex Buffer");
    if(mesh.index_buffer) |indices| {
       const index_buffer = try renderer.createBufferFromData(indices.rawBytes(), c.SDL_GPU_BUFFERUSAGE_INDEX, "Index Buffer");
        return .{
            .vertex_buffer = vertex_buffer,
            .element_count = indices.size(),
            .index_buffer = index_buffer,
            .index_element_type = indices.elementType(),
        };

    }

    return .{
        .vertex_buffer = vertex_buffer,
        .element_count = mesh.num_vertices,
        .index_buffer = null,
        .index_element_type = 0,
    };
}

pub fn deinit(self: Self, renderer: *Renderer) void {
    renderer.releaseBuffer(self.vertex_buffer);
    if (self.index_buffer) |idx| {
        renderer.releaseBuffer(idx);
    }
}

pub fn bind(self: Self, pass: *RenderPass, index: u32) void {
    const vertex_binding = c.SDL_GPUBufferBinding{ .buffer = self.vertex_buffer.handle, .offset = 0 };
    pass.bindVertexBuffers(index, &.{vertex_binding});
    
    if (self.index_buffer) |buffer| {
        const index_binding = c.SDL_GPUBufferBinding{ .buffer = buffer.handle, .offset = 0 };
        pass.bindIndexBuffers(&index_binding, self.index_element_type);
    } 
}
