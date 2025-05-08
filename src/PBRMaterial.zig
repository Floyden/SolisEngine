const texture = @import("renderer/texture.zig");
const SamplerHandle = @import("renderer/sampler.zig").Handle;
const TextureDefaults = @import("defaults.zig").TextureDefaults;
const c = @import("solis").external.c;
const Self = @This();

// Base colors. If the texture is defined, the final base color will be base_color * base_color_texture_sample
base_color: [4]f32 = .{ 1.0, 1.0, 1.0, 1.0 },
base_color_texture: ?texture.Handle = null,

// Contains the ambient occlusion, metallic and roughness textures in the respective RGB channels.
metallic_roughness_texture: ?texture.Handle = null,

// How metallic the material appears. Allowed values are [0.0, 1.0].
// If the texture is defined (green channel of metallic_roughness_texture),
// the final value will be metallic * metallic_texture_sample
metallic: f32 = 0.0,

// How metallic the material appears. Allowed values are [0.0, 1.0].
// If the texture is defined (blue channel of metallic_roughness_texture),
// the final value will be roughness * roughness_texture_sample
roughness: f32 = 0.0,

normal_texture: ?texture.Handle = null,

pub const UniformBinding = extern struct {
    base_color: [4]f32,
    metallic: f32,
    roughness: f32,

    pub fn toBuffer(self: *const UniformBinding) *const [@sizeOf(UniformBinding)]u8 {
        return @ptrCast(self);
    }
};

pub fn createUniformBinding(self: Self) UniformBinding {
    return .{
        .base_color = self.base_color,
        .metallic = self.metallic,
        .roughness = self.roughness,
    };
}

pub fn createSamplerBinding(self: Self, sampler: SamplerHandle) [3]c.SDL_GPUTextureSamplerBinding {
    // TODO: store sampler somewhere else
    return [_]c.SDL_GPUTextureSamplerBinding{
        .{ .sampler = sampler.id, .texture = if (self.base_color_texture) |tex| tex.id else TextureDefaults.get().base_tex.id },
        .{ .sampler = sampler.id, .texture = if (self.normal_texture) |tex| tex.id else TextureDefaults.get().normals_tex.id },
        .{ .sampler = sampler.id, .texture = if (self.metallic_roughness_texture) |tex| tex.id else TextureDefaults.get().metal_rough_tex.id },
    };
}
