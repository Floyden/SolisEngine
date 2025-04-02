pub const PixelFormat = @import("zigimg").PixelFormat;
const c = @import("solis").external.c;

pub const Handle = struct {
    id: *c.SDL_GPUTexture,
};

pub const Description = struct {
    width: u32,
    height: u32,
    depth: u32, // depth or layercount
    usage: u32,
    format: PixelFormat,
    label: ?[]const u8 = null,
};
