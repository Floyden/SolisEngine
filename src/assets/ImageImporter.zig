const std = @import("std");
const solis = @import("solis");

const Allocator = std.mem.Allocator;
const Image = solis.Image;
const zigimg = solis.zigimg;

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
