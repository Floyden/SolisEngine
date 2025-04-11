const Self = @This();
const c = @import("solis").external.c;
const Shader = @import("Shader.zig");

handle: *c.SDL_GPUGraphicsPipeline,

pub const Description = struct {
    vertex_shader: Shader,
    fragment_shader: Shader,
};
