const std = @import("std");
const matrix = @import("matrix.zig");
const Matrix3f = matrix.Matrix3f;
const Matrix4f = matrix.Matrix4f;

pub fn Quaternion(comptime T: type) type {
    return struct {
        const Self = @This();
        w: T,
        x: T,
        y: T,
        z: T,

        pub const identity = Self{ .x = 0, .y = 0, .z = 0, .w = 1 };

        pub fn fromXYZW(data: [4]T) Self {
            return .{
                .x = data[0],
                .y = data[1],
                .z = data[2],
                .w = data[3],
            };
        }

        pub fn fromWXYZ(data: [4]T) Self {
            return .{
                .w = data[0],
                .x = data[1],
                .y = data[2],
                .z = data[3],
            };
        }

        pub fn fromMatrix3(rot: matrix.Matrix3f) Self {
            var quat: Self = undefined;
            var s: T = 1.0;
            if (rot.at(2, 2) < 0) {
                if (rot.at(1, 1) < rot.at(0, 0)) { // x-form
                    s += rot.at(0, 0) - rot.at(1, 1) - rot.at(2, 2);
                    quat = Self{ .x = s, .y = rot.at(0, 1) + rot.at(1, 0), .z = rot.at(0, 2) + rot.at(2, 0), .w = rot.at(1, 2) - rot.at(2, 1) };
                } else { // y-form
                    s -= rot.at(0, 0) + rot.at(1, 1) - rot.at(2, 2);
                    quat = Self{ .x = rot.at(0, 1) + rot.at(1, 0), .y = s, .z = rot.at(0, 2) + rot.at(2, 0), .w = rot.at(1, 2) - rot.at(2, 1) };
                }
            } else {
                if (rot.at(0, 0) < -rot.at(1, 1)) { // z-form
                    s -= rot.at(0, 0) - rot.at(1, 1) + rot.at(2, 2);
                    quat = Self{ .x = rot.at(0, 2) + rot.at(2, 0), .y = rot.at(1, 2) + rot.at(2, 1), .z = s, .w = rot.at(0, 1) - rot.at(1, 0) };
                } else { // w-form
                    s += rot.at(0, 0) + rot.at(1, 1) + rot.at(2, 2);
                    quat = Self{ .x = rot.at(1, 2) - rot.at(2, 1), .y = rot.at(0, 2) - rot.at(2, 0), .z = rot.at(0, 1) + rot.at(1, 0), .w = s };
                }
            }

            return quat.mult(0.5 / @sqrt(s));
        }

        pub fn multMut(a: *Self, b: anytype) void {
            if (comptime @TypeOf(b) == Self) { // Quaternion x Quaternion
                const w = a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z;
                const x = a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y;
                const y = a.w * b.y + a.y * b.w + a.z * b.x - a.x * b.z;
                const z = a.w * b.z + a.z * b.w + a.x * b.y - a.y * b.x;

                a.w = w;
                a.x = x;
                a.y = y;
                a.z = z;
            } else if (comptime @TypeOf(b) == T) { // Scalar multiplication
                a.w *= b;
                a.x *= b;
                a.y *= b;
                a.z *= b;
            }
        }

        pub fn mult(a: Self, b: anytype) Self {
            var res = a;
            res.multMut(b);
            return res;
        }

        pub fn toMatrix3(a: Self) matrix.Matrix(T, 3, 3) {
            const xx = a.x * a.x;
            const yy = a.y * a.y;
            const zz = a.z * a.z;
            const ww = a.w * a.w;
            const xy = a.x * a.y;
            const xz = a.x * a.z;
            const xw = a.x * a.w;
            const yz = a.y * a.z;
            const yw = a.y * a.w;
            const zw = a.z * a.w;
            return matrix.Matrix(T, 3, 3).from(&[_]T{
                2 * (ww + xx) - 1,
                2 * (xy - zw),
                2 * (xz + yw),
                2 * (xy + zw),
                2 * (ww + yy) - 1,
                2 * (yz - xw),
                2 * (xz - yw),
                2 * (yz + xw),
                2 * (ww + zz) - 1,
            });
        }

        pub fn toMatrix4(self: Self) Matrix4f {
            return self.toMatrix3().resize(4, 4);
        }
    };
}

test "quaternion multiplication" {
    const a = Quaternion(f32){ .x = 1, .y = 0, .z = 1, .w = 0 };
    const b = Quaternion(f32){ .x = 1, .y = 0.5, .z = 0.5, .w = 0.75 };

    const result = a.mult(b);

    const expected = Quaternion(f32){
        .x = 0.25,
        .y = 0.5,
        .z = 1.25,
        .w = -1.5,
    };
    try std.testing.expectApproxEqAbs(result.x, expected.x, 0.0001);
    try std.testing.expectApproxEqAbs(result.y, expected.y, 0.0001);
    try std.testing.expectApproxEqAbs(result.z, expected.z, 0.0001);
    try std.testing.expectApproxEqAbs(result.w, expected.w, 0.0001);
}

test "quaternion identity" {
    const a = Quaternion(i32){ .x = 0, .y = 0, .z = 0, .w = 1 };
    const b = Quaternion(i32){ .x = 1, .y = 2, .z = 3, .w = 4 };

    const result1 = a.mult(b);
    const result2 = b.mult(a);

    try std.testing.expectEqual(b, result1);
    try std.testing.expectEqual(b, result2);
}

test "quaternion to matrix" {
    const a = Quaternion(f32){ .x = 0, .y = 0, .z = @sqrt(2.0) / 2.0, .w = @sqrt(2.0) / 2.0 };
    const b = Quaternion(f32){ .w = 1, .x = 0, .y = 0, .z = 0 };
    const c = Quaternion(f32){ .x = @sqrt(2.0) / 2.0, .y = 0, .z = 0.0, .w = -@sqrt(2.0) / 2.0 };

    const res_a = a.toMatrix3();
    const res_b = b.toMatrix3();
    const res_c = c.toMatrix3();
    const expected_a = matrix.Matrix3f.from(&[_]f32{
        0.0, -1.0, 0.0,
        1.0, 0.0,  0.0,
        0.0, 0.0,  1.0,
    });
    const expected_b = matrix.Matrix3f.from(&[_]f32{
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
        0.0, 0.0, 1.0,
    });
    const expected_c = matrix.Matrix3f.from(&[_]f32{
        1.0, 0.0, 0.0,
        0.0, 0.0, 1.0,
        0.0, -1.0, 0.0,
    });

    for (0..9) |i| {
        try std.testing.expectApproxEqAbs(expected_a.data[i], res_a.data[i], 0.01);
        try std.testing.expectApproxEqAbs(expected_b.data[i], res_b.data[i], 0.01);
        try std.testing.expectApproxEqAbs(expected_c.data[i], res_c.data[i], 0.01);
    }
}
