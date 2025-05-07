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
    environment: TextureHandle,

    pub fn init(allocator: std.mem.Allocator, renderer: *Renderer) !void {
        const base = Image.init_fill(&[_]u8{ 255, 255, 255, 255 }, .{ .width = 1, .height = 1 }, .rgba8unorm, allocator);
        const normals = Image.init_fill(&[_]u8{ 128, 128, 255, 255 }, .{ .width = 1, .height = 1 }, .rgba8unorm, allocator);
        const metal_rough = Image.init_fill(&[_]u8{ 255, 255, 255, 255 }, .{ .width = 1, .height = 1 }, .rgba8unorm, allocator);
        const black_cube = Image.init_fill(&[_]u8{ 0, 0, 0, 0 }, .{ .width = 4, .height = 3 }, .rgba8unorm, allocator);

        const base_tex = try renderer.createTextureFromImage(base);
        const normals_tex = try renderer.createTextureFromImage(normals);
        const metal_rough_tex = try renderer.createTextureFromImage(metal_rough);
        const environment = try renderer.createCubeTextureFromImage(black_cube);

        texture_defaults = TextureDefaults{
            .base = base,
            .normals = normals,
            .metal_rough = metal_rough,
            .base_tex = base_tex,
            .normals_tex = normals_tex,
            .metal_rough_tex = metal_rough_tex,
            .environment = environment,
        };
    }

    pub fn deinit(renderer: *Renderer) void {
        if(texture_defaults) |*default| {
            default.base.deinit();
            default.normals.deinit();
            default.metal_rough.deinit();
            renderer.releaseTexture(default.base_tex);
            renderer.releaseTexture(default.normals_tex);
            renderer.releaseTexture(default.metal_rough_tex);
            renderer.releaseTexture(default.environment);
        }
    }

    pub fn get() TextureDefaults {
        if(texture_defaults == null) std.debug.panic("Failed to initialize TextureDefaults", .{});
        return texture_defaults.?;
    }
};

pub var texture_defaults: ?TextureDefaults = null;
