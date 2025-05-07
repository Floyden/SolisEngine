const PixelFormat = @import("zigimg").PixelFormat;
const std = @import("std");
const c = @import("solis").external.c;
const Extent3d = @import("solis").Extent3d;

pub const Handle = struct {
    id: *c.SDL_GPUTexture,
};

pub const Description = struct {
    extent: Extent3d,
    type: Type,
    usage: u32,
    format: Format,
    label: ?[]const u8 = null,
};

pub const Type = enum {
    image2d,
    image2d_array,
    image3d,
    cube,
    cube_array,

    pub fn toSDLFormat(self: Type) u32 {
        switch (self) {
            .image2d => return c.SDL_GPU_TEXTURETYPE_2D,
            .image2d_array => return c.SDL_GPU_TEXTURETYPE_2D_ARRAY,
            .image3d => return c.SDL_GPU_TEXTURETYPE_3D,
            .cube => return c.SDL_GPU_TEXTURETYPE_CUBE,
            .cube_array => return c.SDL_GPU_TEXTURETYPE_CUBE_ARRAY,
        }
    }
};

pub const Format = enum {
    rgba8unorm, // rgba channels, 8 bit integer per channel
    depth16unorm, // depth texture, 16 bit integer

    pub fn fromPixelFormat(format: PixelFormat) Format {
        switch (format) {
            .rgba32 => return .rgba8unorm,
            .grayscale16 => return .depth16unorm,
            else => {
                std.log.err("Following format is not implemented: {any}", .{format});
                @panic("");
            },
        }
    }

    pub fn toSDLFormat(self: Format) u32 {
        switch (self) {
            .rgba8unorm => return c.SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM,
            .depth16unorm => return c.SDL_GPU_TEXTUREFORMAT_D16_UNORM,
        }
    }

    pub fn byteCount(self: Format) u32 {
        switch (self) {
            .rgba8unorm => return 4,
            .depth16unorm => return 2,
        }
    }
};
