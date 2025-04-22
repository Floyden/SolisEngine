// From https://github.com/ziglang/zig/issues/19858#issuecomment-2369861301

pub fn to_usize(self: TypeId) usize {
    return @intFromPtr(self);
}

pub const TypeId = *const struct {
    name: [*]const u8,
};

pub inline fn typeId(comptime T: type) TypeId {
    return &struct {
        var id: @typeInfo(TypeId).pointer.child = .{.name = @typeName(T)};
    }.id;
}

