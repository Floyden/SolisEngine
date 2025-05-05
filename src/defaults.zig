const std = @import("std");
const Image = @import("Image.zig");
const Renderer = @import("Renderer.zig");
const TextureHandle = @import("renderer/texture.zig").Handle;

pub const TextureDefaults = struct {
    base: Image,
    normals: Image,
    metal_rough: Image,
    base_tex: TextureHandle,
    normals_tex: TextureHandle,
    metal_rough_tex: TextureHandle,

    pub fn init(allocator: std.mem.Allocator, renderer: *Renderer) !TextureDefaults {
        const base = Image.init_fill(&[_]u8{ 255, 255, 255, 255 }, .{ .width = 1, .height = 1 }, .rgba8unorm, allocator);
        const normals = Image.init_fill(&[_]u8{ 128, 128, 255, 255 }, .{ .width = 1, .height = 1 }, .rgba8unorm, allocator);
        const metal_rough = Image.init_fill(&[_]u8{ 255, 255, 255, 255 }, .{ .width = 1, .height = 1 }, .rgba8unorm, allocator);

        const base_tex = try renderer.createTextureFromImage(base);
        const normals_tex = try renderer.createTextureFromImage(normals);
        const metal_rough_tex = try renderer.createTextureFromImage(metal_rough);

        return TextureDefaults{
            .base = base,
            .normals = normals,
            .metal_rough = metal_rough,
            .base_tex = base_tex,
            .normals_tex = normals_tex,
            .metal_rough_tex = metal_rough_tex,
        };
    }

    pub fn deinit(self: *TextureDefaults, renderer: *Renderer) void {
        self.base.deinit();
        self.normals.deinit();
        self.metal_rough.deinit();
        renderer.releaseTexture(self.base_tex);
        renderer.releaseTexture(self.normals_tex);
        renderer.releaseTexture(self.metal_rough_tex);
    }
};

pub var texture_defaults: ?TextureDefaults = null;
