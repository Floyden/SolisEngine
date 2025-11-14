const std = @import("std");
const solis = @import("solis");

const Allocator = std.mem.Allocator;
const Image = solis.Image;
const zigimg = solis.zigimg;

const Self = @This();

pub fn import(allocator: Allocator, path: []const u8) ?Image {
    var buffer: [4096]u8 = undefined;
    const fd = std.fs.cwd().openFile(path, .{ .mode = .read_only }) catch |e| {
        std.log.err("ImageImporter: Failed to open file: {s}, Error: {}", .{ path, e });
        return null;
    };
    defer fd.close();

    var reader = fd.reader(&buffer);
    const data = reader.interface.readAlloc(allocator, fd.getEndPos() catch @panic("Fail")) catch @panic("Fail");
    defer allocator.free(data);

    var image = zigimg.Image.fromMemory(allocator, data) catch |e| {
        std.log.err("ImageImporter: {}, Path: {s}", .{ e, path });
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
