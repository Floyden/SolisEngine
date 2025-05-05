const matrix = @import("matrix.zig");
const Matrix4f = matrix.Matrix4f;
const Matrix3f = matrix.Matrix3f;

const Self = @This();

position: [3]f32 = .{ 0.0, 0.0, 0.0 },
orientation: Matrix3f = .identity,
fov: f32 = 45.0,
z_near: f32 = 0.01,
z_far: f32 = 100.0,
aspect: f32,

pub fn projectionMatrix(self: Self) Matrix4f {
    return matrix.perspective(self.fov, self.aspect, self.z_near, self.z_far);
}

pub fn viewMatrix(self: Self) Matrix4f {
    var view = Matrix4f.diagonal_init(1.0);
    for (0..3) |y| {
        for (0..3) |x| {
            view.atMut(x, y).* = self.orientation.at(x, y);
        }
    }
    for (0..3) |y| {
        view.atMut(3, y).* = self.position[y];
    }

    return view;
}
