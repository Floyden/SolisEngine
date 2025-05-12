const c = @import("solis").external.c;
const Shader = @import("Shader.zig");

const Self = @This();

handle: *c.SDL_GPUGraphicsPipeline,
vertex_shader: Shader,
fragment_shader: Shader,

pub const Description = struct {
    vertex_shader: Shader,
    fragment_shader: Shader,
};
