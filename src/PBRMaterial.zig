const texture = @import("renderer/texture.zig");
const SamplerHandle = @import("renderer/sampler.zig").Handle;
const c = @import("solis").external.c;
const Self = @This();

// Base colors. If the texture is defined, the final base color will be base_color * base_color_texture_sample
base_color: [4]f32 = .{ 1.0, 1.0, 1.0, 1.0 },
base_color_texture: ?texture.Handle = null,

// How metallic the material appears. Allowed values are [0.0, 1.0].
// If the texture is defined, the final value will be metallic * metallic_texture_sample
metallic: f32 = 0.0,
metallic_texture: ?texture.Handle = null,

pub const UniformBinding = extern struct {
    base_color: [4] f32,
    metallic: f32,

    pub fn toBuffer(self: *const UniformBinding) *const [@sizeOf(UniformBinding)] u8 {
        return @ptrCast(self);
    }
};

pub fn createUniformBinding(self: Self) UniformBinding {
    return .{
        .base_color = self.base_color,
        .metallic = self.metallic,
    };
}
