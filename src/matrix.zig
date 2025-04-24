const std = @import("std");

pub fn Matrix(T: type, rows: usize, cols: usize) type {
    return extern struct {
        const Self = @This();
        const Cols = cols;
        const Rows = rows;
        data: [rows * cols]T,

        pub fn diagonal_init(value: T) Self {
            var res = Self.zero;
            for (0..@min(rows, cols)) |i| {
                res.atMut(i, i).* = value;
            }
            return res;
        }

        pub fn from(values: []const T) Self {
            std.debug.assert(values.len == cols * rows);
            var self: Self = undefined;
            @memcpy(self.data[0..], values);
            return self;
        }

        pub fn at(self: Self, x: usize, y: usize) T {
            return self.data[y * cols + x];
        }
        pub fn atMut(self: *Self, x: usize, y: usize) *T {
            return &self.data[y * cols + x];
        }

        fn MultResultType(other: type) type {
            return Matrix(T, rows, other.Cols);
        }

        pub fn mult(self: Self, other: anytype) MultResultType(@TypeOf(other)) {
            const OtherType = @TypeOf(other);
            const ResType = MultResultType(OtherType);
            comptime if(Self.Cols != OtherType.Rows) @compileError("Mismatched matrices");
            var res = ResType.zero;
            for (0..Rows) |y| {
                for (0..ResType.Cols) |x| {
                    var val: T = 0;
                    for (0..cols) |i| {
                        val += self.at(i, y) * other.at(x, i);
                    }
                    res.atMut(x, y).* = val;
                }
            }
            return res;
        }

        pub fn rotation(_axis: [3]T, angle: T) Self {
            comptime if (rows != cols) @compileError("Matrix is not square");
            comptime if (rows < 3 or rows > 4) @compileError("Rotation is currently only implemented for 3x3 and 4x4 matrices");

            const rad = angle * std.math.pi / 180.0;
            const sin = @sin(rad);
            const cos = @cos(rad);
            const c1 = 1.0 - cos;

            var res = Self.zero;
            if (comptime rows == 4) {
                res.data[15] = 1;
            }

            const axis: @Vector(3, T) = _axis;
            const len = std.math.sqrt(axis[0] * axis[0] + axis[1] * axis[1] + axis[2] * axis[2]);
            const u = axis / @as(@Vector(3, T), @splat(len));

            for (0..3) |i| {
                res.data[i * 4 + (i + 1) % 3] = u[(i + 2) % 3] * sin;
                res.data[i * 4 + (i + 2) % 3] = -u[(i + 1) % 3] * sin;
            }
            for (0..3) |i| {
                for (0..3) |j| {
                    res.data[i * 4 + j] += c1 * u[i] * u[j] + if (i == j) cos else 0.0;
                }
            }
            return res;
        }

        pub fn transpose(self: Self) Matrix(T, cols, rows) {
            var res = Matrix(T, cols, rows).zero;

            for (0..rows) |y| {
                for (0..cols) |x| {
                    res.atMut(y, x).* = self.at(x, y);
                }
            }

            return res;
        }

        pub const zero: Self = std.mem.zeroes(@This());
        pub const identity = diagonal_init(1);
    };
}

test "identity mult" {
    const matrix1 = Matrix(f32, 4, 3).identity;
    const matrix2 = Matrix(f32, 3, 4).identity;
    const res = matrix2.mult(matrix1);
    std.debug.assert(std.mem.eql(f32, &res.data, &Matrix(f32, 3, 3).identity.data));

    const matrix3 = Matrix3f{ .data = .{ 1, 2, 3, 4, 5, 6, 7, 8, 9 } };
    const res2 = matrix3.mult(res);
    const res3 = res.mult(matrix3);
    std.debug.assert(std.mem.eql(f32, &res2.data, &matrix3.data));
    std.debug.assert(std.mem.eql(f32, &res3.data, &matrix3.data));
}

pub const Matrix3f = Matrix(f32, 3, 3);
pub const Matrix4f = Matrix(f32, 4, 4);

pub fn perspective(fovy: f32, aspect: f32, znear: f32, zfar: f32) Matrix4f {
    const f = 1.0 / @tan(fovy * 0.5);
    var res = Matrix4f.zero;

    res.data[0] = f / aspect;
    res.data[5] = f;
    res.data[10] = (zfar) / (znear - zfar);
    res.data[11] = -1.0;
    res.data[14] = (znear * zfar) / (znear - zfar);
    res.data[15] = 0.0;

    return res;
}
