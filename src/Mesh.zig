const std = @import("std");
const vertex_data = @import("vertex_data.zig");

// pub const IndexBufferType = enum { short, int };
const Self = @This();

pub const IndexBuffer = union(enum) {
    byte: []u8,
    short: []u16,
    int: []u32,
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

pub fn rearrange(self: *Self, new_description: []const vertex_data.ElementDesc) !void {
    var old_vertex_size: u32 = 0;
    for (self.vertex_description.items) |desc|
        old_vertex_size += desc.type.size();

    var new_vertex_size: u32 = 0;
    for (new_description) |desc|
        new_vertex_size += desc.type.size();

    const new_data = self.allocator.alloc(u8, self.num_vertices * new_vertex_size) catch @panic("OOM");

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
        }
    }

    self.allocator.free(self.data.?);
    self.data = new_data;
    self.vertex_description.clearRetainingCapacity();
    self.vertex_description.appendSlice(new_description) catch @panic("OOM");
}
