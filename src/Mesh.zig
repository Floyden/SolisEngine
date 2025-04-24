const std = @import("std");
const vertex_data = @import("vertex_data.zig");

// pub const IndexBufferType = enum { short, int };
const Self = @This();

pub const IndexBuffer = union(enum) {
    byte: []u8,
    short: []u16,
    int: []u32,

    pub fn size(self: IndexBuffer) usize {
        return switch (self) {
            .byte => self.byte.len,
            .short => self.short.len,
            .int => self.int.len,
        };
    }

    pub fn get(self: IndexBuffer, index: usize) u32 {
        return switch (self) {
            .byte => self.byte[index],
            .short => self.short[index],
            .int => self.int[index],
        };
    }
};

pub const Face = struct {
    desc: *const []vertex_data.ElementDesc,
    vertices: [3][]u8,

    pub fn positions(self: Face) ?[3][]f32 {
        var offset : u32 = 0; 
        const desc = for(self.desc.*) |desc| { 
            if(desc.usage == .position) break desc;
            offset += desc.type.size();
        } else return null;

        return .{
            @alignCast(@ptrCast(self.vertices[0][offset..offset+desc.type.size()])),
            @alignCast(@ptrCast(self.vertices[1][offset..offset+desc.type.size()])),
            @alignCast(@ptrCast(self.vertices[2][offset..offset+desc.type.size()])),
        };
    }
};

pub const FaceIter = struct {
    mesh: *Self,
    index: u32,

    pub fn next(self: *FaceIter) ?Face {
        var face = Face {.desc = &self.mesh.vertex_description.items, .vertices = undefined };
        const vertex_size = self.mesh.vertexSize();

        if(self.mesh.index_buffer) |buffer| {
            if(self.index >= buffer.size()) return null;
            const indices = [3]u32 {
                buffer.get(self.index),
                buffer.get(self.index + 1),
                buffer.get(self.index + 2),
            };
            
            face.vertices = .{
                self.mesh.data.?[indices[0] * vertex_size .. (indices[0] + 1) * vertex_size],
                self.mesh.data.?[indices[1] * vertex_size .. (indices[1] + 1) * vertex_size],
                self.mesh.data.?[indices[2] * vertex_size .. (indices[2] + 1) * vertex_size],
            };
        } else {
            return null;
        }
        self.index += 3;
        return face;
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
    for(self.vertex_description.items) |desc| size += desc.type.size();
    return size;
}

pub fn faces(self: *Self) FaceIter {
    return FaceIter{
        .index = 0,
        .mesh = self,
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

    // if(calculate_normals)self.calculateNormals();
    // if(calculate_tangents)self.calculateTangents();
}
