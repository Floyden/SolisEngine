const c = @import("solis").external.c;

pub const Handle = struct {
    id: *c.SDL_GPUSampler,
};

pub const Description = struct {
    min_filter: u32 = c.SDL_GPU_FILTER_NEAREST,
    mag_filter: u32 = c.SDL_GPU_FILTER_NEAREST,
    mipmap_mode: u32 = c.SDL_GPU_SAMPLERMIPMAPMODE_NEAREST,
    address_mode_u: u32 = c.SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE,
    address_mode_v: u32 = c.SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE,
    address_mode_w: u32 = c.SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE,
    mip_lod_bias: f32 = 0.0,
    max_anisotropy: ?f32 = null,
    compare_op: ?u32 = null,
    min_lod: f32 = 0.0,
    max_lod: f32 = 32.0,

    label: ?[]const u8 = null,
};
