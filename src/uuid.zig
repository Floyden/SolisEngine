const std = @import("std");

pub const Uuid = u128;

pub fn new() Uuid {
    var uuid = std.crypto.random.int(Uuid);

    uuid &= ~@as(Uuid, 0xF << 76);
    uuid |= (0x4 << 76); // Set bits to 0100

    uuid &= ~@as(Uuid, 0x3 << 62);
    uuid |= (0x2 << 62); // Set bits to 10

    return uuid;
}

pub fn serialize(uuid: Uuid) [36]u8 {
    var buf: [36]u8 = undefined;
    _ = std.fmt.bufPrint(&buf, "{x:0>8}-{x:0>4}-{x:0>4}-{x:0>4}-{x:0>12}", .{
        @byteSwap(@as(u32, @intCast(uuid & 0xFFFFFFFF))),
        @byteSwap(@as(u16, @intCast((uuid >> 32) & 0xFFFF))),
        @byteSwap(@as(u16, @intCast((uuid >> 48) & 0xFFFF))),
        @byteSwap(@as(u16, @intCast((uuid >> 64) & 0xFFFF))),
        @byteSwap(@as(u48, @intCast((uuid >> 80) & 0xFFFFFFFFFFFF))),
    }) catch unreachable;
    return buf;
}

test "uuid" {
    const uuid = new();
    const uuid2 = new();

    std.testing.expect(uuid != uuid2) catch @panic("If you can read this, you either got really lucky or something is really wrong. Try running the test again.");
}

test "serialize" {
    const uuid: Uuid = 0xfedcba9876543210fedcba9876543210;
    const slice = serialize(uuid);
    try std.testing.expectEqualSlices(u8, "10325476-98ba-dcfe-1032-547698badcfe", &slice);
}
