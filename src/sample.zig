const std = @import("std");

const data =
    \\ {
    \\     "attributes": {
    \\         "attr1": 1,
    \\         "attr3": 3
    \\     }
    \\ }
;

const Attribute = union(enum) {
    attr1: i32,
    attr2: i32,
    attr3: i32,
    // may contain more attributes
};

const Parsed = struct { attributes: std.json.ArrayHashMap(i32) };

pub fn main() !void {
    const res = try std.json.parseFromSlice(Parsed, std.heap.page_allocator, data, .{ .ignore_unknown_fields = true });
    std.log.info("{}", .{res});
}
