const std = @import("std");
const solis = @import("solis");

const Allocator = std.mem.Allocator;
const Image = solis.Image;
const zigimg = solis.zigimg;

const Self = @This();

pub fn import(allocator: Allocator, reader: *std.Io.Reader, meta: solis.assets.Server.ImportMeta) ?Image {
    const data = reader.readAlloc(allocator, meta.length) catch @panic("Fail");
    defer allocator.free(data);

    var image = zigimg.Image.fromMemory(allocator, data) catch |e| {
        std.log.err("ImageImporter: {}, Path: {s}", .{ e, meta.path });
        return null;
    };

    // TODO: Remove this
    if (image.pixelFormat() != .rgba32)
        image.convert(allocator, .rgba32) catch return null;
    const res = Image.init_fill(
        image.rawBytes(),
        .{ .width = @intCast(image.width), .height = @intCast(image.height) },
        Image.TextureFormat.fromPixelFormat(image.pixelFormat()),
        allocator,
    );
    return res;
}
