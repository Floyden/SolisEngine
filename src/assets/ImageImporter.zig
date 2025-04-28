const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const zigimg = @import("zigimg");
const Image = @import("solis").Image;

const Self = @This();

pub fn import(allocator: Allocator, path: []const u8) ?Image {
    var image = zigimg.Image.fromFilePath(allocator, path) catch |e| {
        std.log.err("ImageImporter: {?}, Path: {s}", .{ e, path });
        return null;
    };

    // TODO: Remove this
    if (image.pixelFormat() != .rgba32)
        image.convert(.rgba32) catch return null;
    const res = Image.init_fill(
        image.rawBytes(),
        .{ .width = @intCast(image.width), .height = @intCast(image.height) },
        Image.TextureFormat.fromPixelFormat(image.pixelFormat()),
        allocator,
    );
    return res;
}
