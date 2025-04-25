const std = @import("std");
const vertex_data = @import("vertex_data.zig");
const _matrix = @import("matrix.zig");
const Matrix = _matrix.Matrix;
const Vector2f = _matrix.Vector2f;
const Vector3f = _matrix.Vector3f;
const Vector4f = _matrix.Vector4f;
const c = @import("solis").external.c;

const Self = @This();

pub const IndexBuffer = union(enum) {
    byte: []u8,
    short: []u16,
    int: []u32,

    pub fn size(self: IndexBuffer) u32 {
        return switch (self) {
            .byte => @intCast(self.byte.len),
            .short => @intCast(self.short.len),
            .int => @intCast(self.int.len),
        };
    }

    pub fn get(self: IndexBuffer, index: usize) u32 {
        return switch (self) {
            .byte => self.byte[index],
            .short => self.short[index],
            .int => self.int[index],
        };
    }

    pub fn rawBytes(self: IndexBuffer) []u8 {
        return switch (self) {
            .byte => self.byte,
            .short => @ptrCast(self.short),
            .int => @ptrCast(self.int),
        };
    }

    pub fn elementType(self: IndexBuffer) u32 {
        return switch (self) {
            .byte => @panic("NotSupported, Sorry"),
            .short => c.SDL_GPU_INDEXELEMENTSIZE_16BIT,
            .int => c.SDL_GPU_INDEXELEMENTSIZE_32BIT,
        };
    }
};

pub const Face = struct {
    desc: *const []vertex_data.ElementDesc,
    vertices: [3][]u8,
    indices: [3]u32,

    pub fn attribute(self: Face, usage: vertex_data.ElementUsage) ?[3][]f32 {
        var offset: u32 = 0;
        const desc = for (self.desc.*) |desc| {
            if (desc.usage == usage) break desc;
            offset += desc.type.size();
        } else return null;

        return .{
            @alignCast(@ptrCast(self.vertices[0][offset .. offset + desc.type.size()])),
            @alignCast(@ptrCast(self.vertices[1][offset .. offset + desc.type.size()])),
            @alignCast(@ptrCast(self.vertices[2][offset .. offset + desc.type.size()])),
        };
    }

    pub fn positions(self: Face) ?[3]*Vector3f {
        const ptr = self.attribute(.position) orelse return null;
        return .{ @ptrCast(ptr[0]), @ptrCast(ptr[1]), @ptrCast(ptr[2]) };
    }

    pub fn normals(self: Face) ?[3]*Vector3f {
        const ptr = self.attribute(.normal) orelse return null;
        return .{ @ptrCast(ptr[0]), @ptrCast(ptr[1]), @ptrCast(ptr[2]) };
    }

    pub fn texcoords(self: Face) ?[3]*Vector2f {
        const ptr = self.attribute(.texcoord) orelse return null;
        return .{ @ptrCast(ptr[0]), @ptrCast(ptr[1]), @ptrCast(ptr[2]) };
    }

    pub fn tangents(self: Face) ?[3]*Vector4f {
        const ptr = self.attribute(.tangent) orelse return null;
        return .{ @ptrCast(ptr[0]), @ptrCast(ptr[1]), @ptrCast(ptr[2]) };
    }
};

pub const FaceIter = struct {
    mesh: *Self,
    index: u32,

    pub fn next(self: *FaceIter) ?Face {
        var face = Face{ .desc = &self.mesh.vertex_description.items, .vertices = undefined, .indices = undefined };
        const vertex_size = self.mesh.vertexSize();

        if (self.mesh.index_buffer) |buffer| {
            if (self.index >= buffer.size()) return null;
            face.indices = [3]u32{
                buffer.get(self.index),
                buffer.get(self.index + 1),
                buffer.get(self.index + 2),
            };

            const data: [*]u8 = self.mesh.data.?.ptr;
            face.vertices = .{
                data[face.indices[0] * vertex_size .. (face.indices[0] + 1) * vertex_size],
                data[face.indices[1] * vertex_size .. (face.indices[1] + 1) * vertex_size],
                data[face.indices[2] * vertex_size .. (face.indices[2] + 1) * vertex_size],
            };
        } else {
            std.log.info("FaceIter.next() not implemented for index-less meshes", .{});
            return null;
        }
        self.index += 3;
        return face;
    }

    pub fn reset(self: *FaceIter) void {
        self.index = 0;
    }
};

pub const ElementIter = struct {
    mesh: *Self,
    index: u32,
    offset: u32,
    element_size: u32,
    vertex_size: u32,

    pub fn next(self: *ElementIter) ?[]f32 {
        const res = self.at(self.index);
        if (res) |_| self.index += 1;
        return @alignCast(@ptrCast(res));
    }

    pub fn nextAs(self: *ElementIter, comptime T: type) ?*T {
        const res = self.at(self.index);
        if (res) |_| self.index += 1;
        return @alignCast(@ptrCast(res));
    }

    pub fn at(self: *ElementIter, index: usize) ?[]u8 {
        if (index >= self.mesh.num_vertices) return null;
        const base_index = index * self.vertex_size + self.offset;
        return self.mesh.data.?[base_index .. base_index + self.element_size];
    }

    pub fn atAs(self: *ElementIter, index: usize, comptime T: type) ?*T {
        if (index >= self.mesh.num_vertices) return null;
        const base_index = index * self.vertex_size + self.offset;
        return @alignCast(@ptrCast(self.mesh.data.?[base_index .. base_index + self.element_size]));
    }

    pub fn reset(self: *ElementIter) void {
        self.index = 0;
    }
};

allocator: std.mem.Allocator,

vertex_description: std.ArrayList(vertex_data.ElementDesc),
index_buffer: ?IndexBuffer,
data: ?[]u8,
num_vertices: u32,

pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .allocator = allocator,
        .vertex_description = std.ArrayList(vertex_data.ElementDesc).init(allocator),
        .index_buffer = null,
        .data = null,
        .num_vertices = 0,
    };
}

pub fn deinit(self: *Self) void {
    self.vertex_description.deinit();
    if (self.index_buffer) |index_buffer|
        self.allocator.free(index_buffer);
    self.allocator.free(self.data);
}

pub fn vertexSize(self: Self) u32 {
    var size: u32 = 0;
    for (self.vertex_description.items) |desc| size += desc.type.size();
    return size;
}

pub fn faces(self: *Self) FaceIter {
    return FaceIter{
        .index = 0,
        .mesh = self,
    };
}

pub fn elements(self: *Self, usage: vertex_data.ElementUsage) ?ElementIter {
    var offset: u32 = 0;
    const element_size = for (self.vertex_description.items) |desc| {
        if (desc.usage == usage) break desc.type.size();
        offset += desc.type.size();
    } else return null;

    var vertex_size: u32 = 0;
    for (self.vertex_description.items) |desc|
        vertex_size += desc.type.size();

    return ElementIter{
        .mesh = self,
        .offset = offset,
        .index = 0,
        .element_size = element_size,
        .vertex_size = vertex_size,
    };
}

pub fn rearrange(self: *Self, new_description: []const vertex_data.ElementDesc) !void {
    var old_vertex_size: u32 = 0;
    for (self.vertex_description.items) |desc|
        old_vertex_size += desc.type.size();

    var new_vertex_size: u32 = 0;
    for (new_description) |desc|
        new_vertex_size += desc.type.size();

    const new_data = self.allocator.alloc(u8, self.num_vertices * new_vertex_size) catch @panic("OOM");

    var calculate_normals = false;
    var calculate_tangents = false;

    for (new_description) |new_desc| {
        const old_desc_opt = for (self.vertex_description.items) |old| {
            if (new_desc.usage == old.usage) break old;
        } else null;

        if (old_desc_opt) |old_desc| {
            for (0..self.num_vertices) |i| {
                const dst_start = i * new_vertex_size + new_desc.offset;
                const src_start = i * old_vertex_size + old_desc.offset;

                @memcpy(new_data[dst_start .. dst_start + new_desc.type.size()], self.data.?[src_start .. src_start + old_desc.type.size()]);
            }
            continue;
        }

        if (new_desc.usage == .color) {
            for (0..self.num_vertices) |i| {
                const dst_start = i * new_vertex_size + new_desc.offset;
                @memset(@as([]f32, @alignCast(@ptrCast(new_data[dst_start .. dst_start + new_desc.type.size()]))), 1.0);
            }
        } else if (new_desc.usage == .normal) {
            calculate_normals = true;
        } else if (new_desc.usage == .tangent) {
            calculate_tangents = true;
        }
    }

    self.allocator.free(self.data.?);
    self.data = new_data;
    self.vertex_description.clearRetainingCapacity();
    self.vertex_description.appendSlice(new_description) catch @panic("OOM");

    if (calculate_normals) self.calculateNormals();
    if (calculate_tangents) self.calculateTangents();
}

pub fn calculateNormals(self: *Self) void {
    // Clear old normals
    var normalIter = self.elements(.normal).?;
    while (normalIter.nextAs(Vector3f)) |normal|
        normal.* = Vector3f.zero;

    var face_iter = self.faces();
    while (face_iter.next()) |face| {
        const positions = face.positions().?;
        const edge1 = positions[1].sub(positions[0].*);
        const edge2 = positions[2].sub(positions[0].*);

        const normal = edge1.cross(edge2).normalize();
        const normals = face.normals().?;
        for (&normals) |dst| dst.addMut(normal);
    }

    normalIter.reset();
    while (normalIter.nextAs(Vector3f)) |normal|
        normal.* = normal.normalize();
}

pub fn calculateTangents(self: *Self) void {
    var bitangents = self.allocator.alloc(Vector3f, self.num_vertices) catch @panic("OOM");
    defer self.allocator.free(bitangents);
    for (bitangents) |*val| val.* = Vector3f.zero;

    var face_iter = self.faces();
    while (face_iter.next()) |face| {
        const positions = face.positions().?;
        const uvs = face.texcoords().?;

        const edge1 = positions[1].sub(positions[0].*);
        const edge2 = positions[2].sub(positions[0].*);

        const duv1 = uvs[1].sub(uvs[0].*);
        const duv2 = uvs[2].sub(uvs[0].*);

        const f = 1.0 / (duv1.at(0) * duv2.at(1) - duv1.at(1) * duv2.at(0));
        const tangent3 = edge1.mult(duv2.at(1)).sub(edge2.mult(duv1.at(1))).mult(f);
        const bitangent = edge1.mult(-duv2.at(0)).add(edge2.mult(duv1.at(0))).mult(f);

        for (face.indices) |index|
            bitangents[index].addMut(bitangent);

        var tangent = Vector4f.zero;
        @memcpy(tangent.data[0..3], &tangent3.data);

        const tangents = face.tangents().?;
        for (&tangents) |val|
            val.addMut(tangent);
    }

    var tangents = self.elements(.tangent).?;
    var normals = self.elements(.normal).?;

    // create average of each tangent and use it to assign the bitangent & handedness
    for (0..self.num_vertices) |i| {
        var tangent = tangents.atAs(i, Vector3f).?;
        tangent.* = tangent.normalize();

        var normal = normals.atAs(i, Vector3f).?;
        // TODO: The minus looks wrong but it works?
        const handedness = -std.math.sign(normal.cross(tangent.*).dot(bitangents[i].normalize()));

        var tangent4 = tangents.atAs(i, Vector4f).?;
        tangent4.atMut(3).* = handedness;
    }
}
