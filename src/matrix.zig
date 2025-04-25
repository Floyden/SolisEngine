const std = @import("std");

pub fn Matrix(T: type, rows: usize, cols: usize) type {
    return extern struct {
        const Self = @This();
        pub const Cols = cols;
        pub const Rows = rows;
        pub const IsVector = Rows == 1 or Cols == 1;
        pub const IsSquare = Rows == Cols;

        data: [Rows * Cols]T,

        pub fn diagonal_init(value: T) Self {
            var res = Self.zero;
            for (0..@min(Rows, Cols)) |i| {
                res.atMut(i, i).* = value;
            }
            return res;
        }

        pub fn from(values: []const T) Self {
            std.debug.assert(values.len == Cols * Rows);
            var self: Self = undefined;
            @memcpy(self.data[0..], values);
            return self;
        }

        fn atMatrix(self: Self, x: usize, y: usize) T {
            return self.data[y * Cols + x];
        }

        fn atVector(self: Self, x: usize) T {
            return self.data[x];
        }

        fn atMatrixMut(self: *Self, x: usize, y: usize) *T {
            return &self.data[y * Cols + x];
        }

        fn atVectorMut(self: *Self, x: usize) *T {
            return &self.data[x];
        }

        pub const at = if(IsVector) atVector else atMatrix;
        pub const atMut = if(IsVector) atVectorMut else atMatrixMut;

        pub fn add(self: Self, other: Self) Self {
            var res = Self.from(&self.data);
            res.addMut(other);
            return res;
        }

        pub fn addMut(self: *Self, other: Self) void {
            for (0..Rows * Cols) |i| self.data[i] += other.data[i];
        }

        pub fn sub(self: Self, other: Self) Self {
            var res = Self.from(&self.data);
            for (0..Rows * Cols) |i| res.data[i] -= other.data[i];
            return res;
        }

        fn MultResultType(other: type) type {
            if (other == T) return Self;
            return Matrix(T, Rows, other.Cols);
        }

        pub fn mult(self: Self, other: anytype) MultResultType(@TypeOf(other)) {
            const OtherType = @TypeOf(other);
            const ResType = MultResultType(OtherType);
            // Scalar multiplication
            if (comptime OtherType == T) {
                var res = Self.from(&self.data);
                for (0..Rows * Cols) |i| res.data[i] *= other;
                return res;
            }

            // Matrix multiplication 
            comptime if (Self.Cols != OtherType.Rows) @compileError("Mismatched matrices");
            var res = ResType.zero;
            for (0..Rows) |y| {
                for (0..ResType.Cols) |x| {
                    var val: T = 0;
                    for (0..Cols) |i| {
                        val += self.at(i, y) * other.at(x, i);
                    }
                    res.atMut(x, y).* = val;
                }
            }
            return res;
        }

        pub fn rotation(_axis: [3]T, angle: T) Self {
            comptime if (!IsSquare) @compileError("Matrix is not square");
            comptime if (Rows < 3 or Rows > 4) @compileError("Rotation is currently only implemented for 3x3 and 4x4 matrices");

            const rad = angle * std.math.pi / 180.0;
            const sin = @sin(rad);
            const cos = @cos(rad);
            const c1 = 1.0 - cos;

            var res = Self.zero;
            if (comptime Rows == 4) {
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

        pub fn transpose(self: Self) Matrix(T, Cols, Rows) {
            var res = Matrix(T, Cols, Rows).zero;

            for (0..Rows) |y| {
                for (0..Cols) |x| {
                    res.atMut(y, x).* = self.at(x, y);
                }
            }

            return res;
        }

        pub fn normalize(self: Self) Self {
            if (comptime !IsVector) @compileError("Normalize for matrices is not implemented");
            const len = self.length();
            var res = Self.from(&self.data);
            for (&res.data) |*val| val.* /= len;
            return res;
        }

        // Returns the length squared
        pub fn length2(self: Self) T {
            if (comptime !IsVector) @compileError("length2 for matrices is not implemented");
            var square_sum: T = 0.0;
            for (self.data) |val| square_sum += val * val;
            return square_sum;
        }

        pub fn length(self: Self) T {
            if (comptime !IsVector) @compileError("length for matrices is not implemented");
            return @sqrt(self.length2());
        }

        pub fn cross(self: Self, other: Self) Self {
            if (comptime !(Rows == 3 and Cols == 1) and !(Rows == 1 and Cols == 3)) @compileError("cross only works with 3d vectors");
            var res = Self.zero;
            res.atMut(0).* = self.at(1) * other.at(2) - self.at(2) * other.at(1);
            res.atMut(1).* = self.at(2) * other.at(0) - self.at(0) * other.at(2);
            res.atMut(2).* = self.at(0) * other.at(1) - self.at(1) * other.at(0);
            return res;
        }

        pub fn dot(self: Self, other: Self) T {
            if (comptime !IsVector) @compileError("dot only works with vectors");
            var res: T = 0.0;
            for (self.data, other.data) |a, b| res += a * b;
            return res;
        }

        // pub fn reduce(self: Self, comptime NewRows: u32, comptime NewCols: u32) Matrix(T, NewRows, NewCols) {
        //     if(comptime Rows < NewRows or Cols < NewCols) @compileError("Cannot increase dimension");
        // }

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

pub const Vector2f = Matrix(f32, 2, 1);
pub const Vector3f = Matrix(f32, 3, 1);
pub const Vector4f = Matrix(f32, 4, 1);

pub const Matrix2f = Matrix(f32, 2, 2);
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
