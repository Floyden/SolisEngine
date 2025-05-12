const std = @import("std");
const solis = @import("solis");

const c = solis.external.c;
const Extent3d = solis.Extent3d;
const PixelFormat = solis.zigimg.PixelFormat;

pub const Handle = struct {
    id: *c.SDL_GPUTexture,
};

pub const Description = struct {
    extent: Extent3d,
    type: Type,
    usage: Usage,
    format: Format,
    label: ?[]const u8 = null,
};

pub const Usage = enum {
    sampler,
    depth_stencil_target,

    pub fn toSDLFormat(self: Usage) u32 {
        return switch (self) {
            .sampler => c.SDL_GPU_TEXTUREUSAGE_SAMPLER,
            .depth_stencil_target => c.SDL_GPU_TEXTUREUSAGE_DEPTH_STENCIL_TARGET,
        };
    }
};

pub const Type = enum {
    image2d,
    image2d_array,
    image3d,
    cube,
    cube_array,

    pub fn toSDLFormat(self: Type) u32 {
        return switch (self) {
            .image2d => c.SDL_GPU_TEXTURETYPE_2D,
            .image2d_array => c.SDL_GPU_TEXTURETYPE_2D_ARRAY,
            .image3d => c.SDL_GPU_TEXTURETYPE_3D,
            .cube => c.SDL_GPU_TEXTURETYPE_CUBE,
            .cube_array => c.SDL_GPU_TEXTURETYPE_CUBE_ARRAY,
        };
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
        return switch (self) {
            .rgba8unorm => c.SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM,
            .depth16unorm => c.SDL_GPU_TEXTUREFORMAT_D16_UNORM,
        };
    }

    pub fn byteCount(self: Format) u32 {
        return switch (self) {
            .rgba8unorm => 4,
            .depth16unorm => 2,
        };
    }
};
