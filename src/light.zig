const std = @import("std");
const matrix = @import("solis").matrix;
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
    _padding: [2]f32 = undefined,
    comptime {
        std.debug.assert(@sizeOf(Light) % 16 == 0);
    }

    pub fn createPoint(position: Vector3f, color: Vector4f, intensity: f32) Light {
        return Light{ .type = .Point, .position = position.resizeFill(4, 1, 1.0), .direction = Vector4f.zero, .color = color, .intensity = intensity };
    }

    pub fn createDirectional(direction: Vector3f, color: Vector4f, intensity: f32) Light {
        return Light{ .type = .Directional, .position = Vector4f.zero, .direction = direction.resizeFill(4, 1, 0.0), .color = color, .intensity = intensity };
    }

    pub fn toBuffer(self: *const Light) *const [@sizeOf(Light)]u8 {
        return @alignCast(@ptrCast(self));
    }
};
