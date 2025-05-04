const matrix = @import("matrix.zig");
const Vector3f = matrix.Vector3f;
const Vector4f = matrix.Vector4f;


pub const Light = extern struct {
    pub const Type = enum(c_int) {
        Point,
        Directional,
        Spotlight,
        Ambient,
    };

    position: Vector4f,
    direction: Vector4f,

    color: Vector4f,
    type: Type,
    intensity: f32,

    pub fn createPoint(position: Vector3f, color: Vector4f, intensity: f32) Light {
        return Light {
            .type = .Point,
            .position = position.resizeFill(4, 1, 1.0),
            .direction = Vector4f.zero,
            .color = color,
            .intensity = intensity
        };
    }
    
    pub fn createDirectional(direction: Vector3f, color: Vector4f, intensity: f32) Light {
        return Light {
            .type = .Directional,
            .position = Vector4f.zero,
            .direction = direction.resizeFill(4, 1, 0.0),
            .color = color,
            .intensity = intensity
        };
    }
    
    pub fn toBuffer(self: *const Light) *const [@sizeOf(Light)]f32 {
        return @alignCast(@ptrCast(self));
    }
};

pub const PointLight = extern struct {
    position: [4]f32,
    color: [4]f32,
    intensity: f32,

    pub fn toBuffer(self: *const PointLight) *const [@sizeOf(PointLight)]f32 {
        return @alignCast(@ptrCast(self));
    }
};

