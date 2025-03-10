const Type = enum {
    Point,
    Directional,
    Spotlight,
    Ambient,
};

pub const PointLight = extern struct {
    position: [4]f32,
    color: [4]f32,
    intensity: f32,

    pub fn toBuffer(self: *const PointLight) *const [@sizeOf(PointLight)]f32 {
        return @alignCast(@ptrCast(self));
    }
};
