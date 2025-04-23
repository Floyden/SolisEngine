const std = @import("std");
const Extent3d = @import("Extent3d.zig");
const SamplerDescription = @import("renderer/sampler.zig").Description;
pub const TextureFormat = @import("renderer/texture.zig").Format;

const Self = @This();

extent: Extent3d,
format: TextureFormat,
// If it is null, use the default sampler.
sampler: ?SamplerDescription,

allocator: std.mem.Allocator,
data: std.ArrayList(u8),

// TODO: convert between image formats
pub fn init_empty(extent: Extent3d, format: TextureFormat, allocator: std.mem.Allocator) Self {
    return Self{
        .extent = extent,
        .format = format,
        .allocator = allocator,
        .sampler = null,
        .data = std.ArrayList(u8).initCapacity(allocator, extent.volume() * format.byteCount()) catch @panic("OOM"),
    };
}

// Fill the image with the given pixel data, repeated until the image is filled
pub fn init_fill(data: []const u8, extent: Extent3d, format: TextureFormat, allocator: std.mem.Allocator) Self {
    var self = init_empty(extent, format, allocator);

    var remaining = self.data.capacity;
    while (remaining >= data.len) : (remaining -= data.len) {
        self.data.appendSliceAssumeCapacity(data);
    }

    if (remaining > 0) {
        self.data.appendSliceAssumeCapacity(data[0..remaining]);
    }

    return self;
}

pub fn deinit(self: *Self) void {
    self.data.deinit();
}

pub fn rawBytes(self: Self) []const u8 {
    return self.data.items;
}

// pub const default : Self = init_fill(&[4]u8{255, 255, 255, 255}, .{.width = 1, .height = 1}, TextureFormat.rgba8unorm, );
// pub const transparent : Self = init_fill(.{.width = 1, .height = 1}, TextureFormat.rgba8unorm, std.heap.PageAllocator);
