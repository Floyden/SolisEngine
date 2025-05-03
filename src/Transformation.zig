const quaternion = @import("quaternion.zig");
const matrix = @import("matrix.zig");
const Matrix3f = matrix.Matrix3f;
const Matrix4f = matrix.Matrix4f;

const Self = @This();

translation: matrix.Vector3f = .zero,
scale: matrix.Vector3f = .ones,
rotation: quaternion.Quaternion(f32) = .identity,

pub fn from_matrix(transform: Matrix4f) Self {
    const translation = matrix.Vector3f.from(transform.column(3).data[0..2]);
    const scale = matrix.Vector3f.from(&[_]f32{ transform.column(0).length(), transform.column(1).length(), transform.column(2).length() });

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

pub fn to_matrix(self: Self) Matrix4f {
    var res = Matrix4f.diagonal_init_slice(self.scale.data[0..2]);
    res = res.mult(self.rotation.toMatrix4());

    res.atMut(3, 0).* = self.translation.at(0);
    res.atMut(3, 1).* = self.translation.at(1);
    res.atMut(3, 2).* = self.translation.at(2);
    return res;
}
