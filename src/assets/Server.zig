const std = @import("std");
const type_id = @import("solis").type_id;
const Handle = @import("handle.zig").Handle;
const HandleAny = @import("handle.zig").HandleAny;
const Self = @This();

allocator: std.mem.Allocator,
importers: std.AutoHashMapUnmanaged(type_id.TypeId, *const anyopaque),
loaded_assets: std.AutoHashMapUnmanaged(HandleAny, *anyopaque),

// TODO: Metadata (Path, Type, ...)

pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .allocator = allocator,
        .importers = .empty,
        .loaded_assets = .empty,
    };
}

pub fn deinit(self: *Self) void {
    self.importers.deinit(self.allocator);

    // TODO: This is currently leaking all assets which were not unloaded.
    self.loaded_assets.deinit(self.allocator);
}

pub fn register_importer(self: *Self, comptime T: type, comptime importer: type) !void {
    try self.importers.put(self.allocator, type_id.typeId(T), importer.import);
}

pub fn load(self: *Self, comptime T: type, path: []const u8) !Handle(T) {
    // TODO: check if the asset has been loaded already.
    // TODO: Figure out error handling
    const importer = @as(*const fn (std.mem.Allocator, path: []const u8) ?T, @ptrCast(self.importers.get(type_id.typeId(T)) orelse return error.ImporterNotFound));
    const handle = Handle(T).new();
    const dest = try self.allocator.create(T);
    dest.* = importer(self.allocator, path) orelse {
        std.log.info("Failed to load asset: {s}", .{path});
        self.allocator.destroy(dest);
        return Handle(T).empty;
    };


    try self.loaded_assets.put(self.allocator, handle.inner, dest);
    return handle;
}

pub fn unload(self: *Self, comptime T: type, handle: Handle(T)) void {
    if(self.loaded_assets.fetchRemove(handle.inner)) |kv| {
        self.allocator.destroy(@as(*T, @alignCast(@ptrCast(kv.value))));
    }
}

pub fn get(self: *Self, comptime T: type, handle: Handle(T)) ?*T {
    const asset = self.loaded_assets.get(handle.inner);
    if (asset) |val| return @alignCast(@ptrCast(val));
    return null;
}
