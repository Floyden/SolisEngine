const std = @import("std");

pub fn Matrix(T: type, rows: usize, cols: usize) type {
    return extern struct {
        const Self = @This();
        pub const Cols = cols;
        pub const Rows = rows;
        pub const IsVector = Rows == 1 or Cols == 1;
        pub const IsSquare = Rows == Cols;

        data: [Rows * Cols]T,

        /// Creates a matrix with all diagonal elements set to value, and all other elements set to zero.
        pub fn diagonal_init(value: T) Self {
            var res = Self.zero;
            for (0..@min(Rows, Cols)) |i| {
                res.atMut(i, i).* = value;
            }
            return res;
        }
        /// Creates a matrix with all diagonal elements set to the values of the slice, and all other elements set to zero.
        /// If the slice is smaller than the dimension, then the remaining diagonal values are set to 1.
        pub fn diagonal_init_slice(values: []const T) Self {
            std.debug.assert(values.len <= @min(Rows, Cols));
            var res = Self.identity;
            for (0..@min(Rows, Cols, values.len)) |i|
                res.atMut(i, i).* = values[i];
            return res;
        }

        /// Constructs a matrix from a flat slice of values. The slice length must be equal to Rows * Cols.
        pub fn from(values: []const T) Self {
            std.debug.assert(values.len == Cols * Rows);
            var self: Self = undefined;
            @memcpy(self.data[0..], values);
            return self;
        }

        /// Constructs a matrix from a tuple. The tuple length must be equal to Rows * Cols.
        pub fn create(values: anytype) Self {
            std.debug.assert(values.len == Cols * Rows);
            var self: Self = undefined;
            inline for (&self.data, values) |*dst, src|
                dst.* = src;
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

        pub const at = if (IsVector) atVector else atMatrix;
        pub const atMut = if (IsVector) atVectorMut else atMatrixMut;

        /// Returns the result of element-wise addition between self and other.
        pub fn add(self: Self, other: Self) Self {
            var res = Self.from(&self.data);
            res.addMut(other);
            return res;
        }

        /// Performs in-place element-wise addition of other into self.
        pub fn addMut(self: *Self, other: Self) void {
            for (0..Rows * Cols) |i| self.data[i] += other.data[i];
        }

        /// Returns the result of element-wise subtraction between self and other.
        pub fn sub(self: Self, other: Self) Self {
            var res = Self.from(&self.data);
            res.subMut(other);
            return res;
        }

        pub fn subMut(self: *Self, other: Self) void {
            for (0..Rows * Cols) |i| self.data[i] -= other.data[i];
        }

        fn MultResultType(other: type) type {
            if (other == T) return Self;
            return Matrix(T, Rows, other.Cols);
        }

        pub fn multMut(self: *Self, other: anytype) void {
            const OtherType = @TypeOf(other);

            // Scalar multiplication
            if (comptime OtherType == T) {
                for (0..Rows * Cols) |i| self.data[i] *= other;
                return;
            } else {
                // TODO: square matrix-matrix multiplication
                @compileError("Mutable Matrix multiplication is not yet implemented");
            }
        }

        /// Performs scalar or matrix multiplication. If other is a scalar, all elements are multiplied by it. If other is a matrix, performs matrix multiplication.
        pub fn mult(self: Self, other: anytype) MultResultType(@TypeOf(other)) {
            const OtherType = @TypeOf(other);
            const ResType = MultResultType(OtherType);
            // Scalar multiplication
            if (comptime OtherType == T) {
                var res = Self.from(&self.data);
                res.multMut(other);
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

        /// Constructs a 3x3 or 4x4 rotation matrix rotating around the given axis by the specified angle (in degrees). Only valid for square matrices of size 3×3 or 4×4
        pub fn rotation(_axis: [3]T, angle: T) Self {
            comptime if (!IsSquare) @compileError("Matrix is not square");
            comptime if (Rows < 3 or Rows > 4) @compileError("Rotation is currently only implemented for 3x3 and 4x4 matrices");

            const rad = angle * std.math.pi / 180.0;
            const sin = @sin(rad);
            const cos = @cos(rad);
            const c1 = 1.0 - cos;

            var res = Self.zero;
            if (comptime Rows == 4) {
                res.atMut(3, 3).* = 1;
            }

            const axis: @Vector(3, T) = _axis;
            const len = std.math.sqrt(axis[0] * axis[0] + axis[1] * axis[1] + axis[2] * axis[2]);
            const u = axis / @as(@Vector(3, T), @splat(len));

            for (0..3) |i| {
                res.atMut((i + 1) % 3, i).* = u[(i + 2) % 3] * sin;
                res.atMut((i + 2) % 3, i).* = -u[(i + 1) % 3] * sin;
            }
            for (0..3) |i| {
                for (0..3) |j| {
                    res.atMut(j, i).* += c1 * u[i] * u[j] + if (i == j) cos else 0.0;
                }
            }
            return res;
        }

        /// Returns the transpose of the matrix, flipping rows and columns
        pub fn transpose(self: Self) Matrix(T, Cols, Rows) {
            var res = Matrix(T, Cols, Rows).zero;

            for (0..Rows) |y| {
                for (0..Cols) |x| {
                    res.atMut(y, x).* = self.at(x, y);
                }
            }

            return res;
        }

        /// Returns the normalized version of a vector (1-row or 1-column matrix). Compile-time error if called on a non-vector
        pub fn normalize(self: Self) Self {
            if (comptime !IsVector) @compileError("Normalize for matrices is not implemented");
            const len = self.length();
            var res = Self.from(&self.data);
            for (&res.data) |*val| val.* /= len;
            return res;
        }

        /// Returns the squared length (magnitude) of a vector. Compile-time error if called on a non-vector
        pub fn length2(self: Self) T {
            if (comptime !IsVector) @compileError("length2 for matrices is not implemented");
            var square_sum: T = 0.0;
            for (self.data) |val| square_sum += val * val;
            return square_sum;
        }

        /// Returns the length (magnitude) of a vector. Compile-time error if called on a non-vector.
        pub fn length(self: Self) T {
            if (comptime !IsVector) @compileError("length for matrices is not implemented");
            return @sqrt(self.length2());
        }

        /// Returns the cross product of two 3D vectors. Only valid for 3d-vectors. Compile-time error otherwise.
        pub fn cross(self: Self, other: Self) Self {
            if (comptime !(Rows == 3 and Cols == 1) and !(Rows == 1 and Cols == 3)) @compileError("cross only works with 3d vectors");
            var res = Self.zero;
            res.atMut(0).* = self.at(1) * other.at(2) - self.at(2) * other.at(1);
            res.atMut(1).* = self.at(2) * other.at(0) - self.at(0) * other.at(2);
            res.atMut(2).* = self.at(0) * other.at(1) - self.at(1) * other.at(0);
            return res;
        }

        /// Returns the dot product of two vectors. Only valid for vectors. Compile-time error otherwise.
        pub fn dot(self: Self, other: Self) T {
            if (comptime !IsVector) @compileError("dot only works with vectors");
            var res: T = 0.0;
            for (self.data, other.data) |a, b| res += a * b;
            return res;
        }

        /// Returns the i-th row of the matrix as a new vector.
        pub fn row(self: Self, i: usize) Matrix(T, 1, Cols) {
            const start = i * Cols;
            return Matrix(T, 1, Cols).from(self.data[start .. start + Cols]);
        }

        /// Returns the j-th column of the matrix as a new vector.
        pub fn column(self: Self, j: usize) Matrix(T, Rows, 1) {
            var col = Matrix(T, Rows, 1).zero;
            var i: usize = 0;
            while (i < Rows) : (i += 1) {
                col.data[i] = self.data[i * Cols + j];
            }
            return col;
        }

        /// Returns the trace (sum of diagonal elements) of a square matrix
        pub fn trace(self: Self) T {
            if (comptime IsSquare) @compileError("trace is only defined for square matrices");
            var res: T = 0;
            for (0..Rows) |i| res += self.at(i, i);
            return res;
        }

        /// Returns a copy of the matrix with the new dimensions.
        /// New diagonal elements are set to 1, all other elements are set to 0.
        pub fn resize(self: Self, comptime NewRows: usize, comptime NewCols: usize) Matrix(T, NewRows, NewCols) {
            var res = Matrix(T, NewRows, NewCols).diagonal_init(1);
            for (0..@min(NewRows, Rows)) |y| {
                // Copy values
                for (0..@min(NewCols, Cols)) |x| {
                    if (comptime IsVector) {
                        const idx = @max(x, y);
                        res.atMut(idx).* = self.at(idx);
                    } else {
                        res.atMut(x, y).* = self.at(x, y);
                    }
                }
            }
            return res;
        }

        /// Returns a copy of the matrix with the new dimensions.
        /// New  elements are set to val.
        pub fn resizeFill(self: Self, comptime NewRows: usize, comptime NewCols: usize, val: T) Matrix(T, NewRows, NewCols) {
            var res: Matrix(T, NewRows, NewCols) = undefined;
            @memset(&res.data, val); // TODO: Writing twice in the same location should be avoided
            for (0..@min(NewRows, Rows)) |y| {
                // Copy values
                for (0..@min(NewCols, Cols)) |x| {
                    if (comptime IsVector) {
                        const idx = @max(x, y);
                        res.atMut(idx).* = self.at(idx);
                    } else {
                        res.atMut(x, y).* = self.at(x, y);
                    }
                }
            }
            return res;
        }

        // pub fn reduce(self: Self, comptime NewRows: u32, comptime NewCols: u32) Matrix(T, NewRows, NewCols) {
        //     if(comptime Rows < NewRows or Cols < NewCols) @compileError("Cannot increase dimension");
        // }

        /// Returns a matrix with all elements set to zero.
        pub const zero: Self = std.mem.zeroes(@This());
        /// Returns a matrix with all elements set to one.
        pub const ones: Self = .{ .data = [_]T{1} ** (Rows * Cols) };
        /// Returns the identity matrix. Only valid for square matrices
        pub const identity = if (IsSquare) diagonal_init(1);
    };
}

test "identity mult" {
    const matrix1 = Matrix(f32, 4, 3).diagonal_init(1);
    const matrix2 = Matrix(f32, 3, 4).diagonal_init(1);
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

    res.atMut(0, 0).* = f / aspect;
    res.atMut(1, 1).* = f;
    res.atMut(2, 2).* = (zfar) / (znear - zfar);
    res.atMut(3, 2).* = (znear * zfar) / (znear - zfar);
    res.atMut(2, 3).* = -1.0;

    return res;
}
