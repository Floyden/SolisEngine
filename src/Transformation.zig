const Quaternion = @import("quaternion.zig").Quaternion(f32);
const matrix = @import("matrix.zig");
const Vector3f = matrix.Vector3f;
const Matrix3f = matrix.Matrix3f;
const Matrix4f = matrix.Matrix4f;

const Self = @This();

translation: Vector3f = .zero,
scale: Vector3f = .ones,
rotation: Quaternion = .identity,

pub fn fromMatrix(transform: Matrix4f) Self {
    const translation = Vector3f.from(transform.column(3).data[0..2]);
    const scale = Vector3f.from(&[_]f32{ transform.column(0).length(), transform.column(1).length(), transform.column(2).length() });

    var rotation_data: [9]f32 = undefined;
    @memcpy(rotation_data[0..2], transform.column(0).mult(scale.at(0)).data[0..2]);
    @memcpy(rotation_data[3..5], transform.column(1).mult(scale.at(1)).data[0..2]);
    @memcpy(rotation_data[6..8], transform.column(2).mult(scale.at(2)).data[0..2]);
    const rotation_matrix = Matrix3f.from(&rotation_data).transpose();

    return Self{
        .translation = translation,
        .scale = scale,
        .rotation = .fromMatrix3(rotation_matrix),
    };
}

pub fn toMatrix(self: Self) Matrix4f {
    var res = Matrix4f.diagonal_init_slice(self.scale.data[0..2]);
    res = res.mult(self.rotation.toMatrix4());

    res.atMut(3, 0).* = self.translation.at(0);
    res.atMut(3, 1).* = self.translation.at(1);
    res.atMut(3, 2).* = self.translation.at(2);
    return res;
}

const std = @import("std");
test "toMatrix" {
    const res_a = (Self {
        .scale = Vector3f.ones,
        .rotation = Quaternion{ .x = @sqrt(2.0) / 2.0, .y = 0, .z = 0.0, .w = -@sqrt(2.0) / 2.0 },
        .translation = Vector3f.from(&[_]f32{1.0, 2.0, 3.0}),
    }).toMatrix();

    const expected_a = Matrix4f.from(&[_]f32{
        1.0, 0.0,  0.0, 1.0,
        0.0, 0.0,  1.0, 2.0,
        0.0, -1.0, 0.0, 3.0,
        0.0, 0.0,  0.0, 1.0,
    });
    for (0..16) |i| {
        try std.testing.expectApproxEqAbs(expected_a.data[i], res_a.data[i], 0.01);
    }
}
