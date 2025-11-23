const std = @import("std");
const solis = @import("solis");

const Handle = @import("handle.zig").Handle;
const HandleAny = @import("handle.zig").HandleAny;
const TypeId = solis.TypeId;
const typeId = solis.typeId;

const Self = @This();

allocator: std.mem.Allocator,
importers: std.AutoHashMapUnmanaged(TypeId, *const anyopaque),
loaded_assets: std.AutoHashMapUnmanaged(HandleAny, *anyopaque),

// TODO: Metadata (Path, Type, ...)
pub const ImportMeta = struct {
    path: []const u8,
    ext: []const u8,
    length: usize,
};

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
    try self.importers.put(self.allocator, typeId(T), importer.import);
}

pub fn load(self: *Self, comptime T: type, path: []const u8) !Handle(T) {
    // TODO: check if the asset has been loaded already.
    // TODO: Figure out error handling
    var file = try std.fs.cwd().openFile(path, .{});
    const stat = try file.stat();
    defer file.close();

    const meta = ImportMeta{
        .path = path,
        .ext = std.fs.path.extension(path),
        .length = stat.size,
    };
    var buffer: [4096]u8 = undefined;
    var reader = file.reader(&buffer);

    const importer = @as(*const fn (std.mem.Allocator, *std.Io.Reader, ImportMeta) ?T, @ptrCast(self.importers.get(typeId(T)) orelse return error.ImporterNotFound));
    const dest = try self.allocator.create(T);
    dest.* = importer(self.allocator, &reader.interface, meta) orelse {
        std.log.info("Failed to load asset: {s}", .{path});
        self.allocator.destroy(dest);
        return Handle(T).empty;
    };

    const handle = Handle(T).new();
    try self.loaded_assets.put(self.allocator, handle.inner, dest);
    return handle;
}

pub fn unload(self: *Self, comptime T: type, handle: Handle(T)) void {
    if (self.loaded_assets.fetchRemove(handle.inner)) |kv| {
        self.allocator.destroy(@as(*T, @ptrCast(@alignCast(kv.value))));
    }
}

pub fn get(self: *Self, comptime T: type, handle: Handle(T)) ?*T {
    const asset = self.loaded_assets.get(handle.inner);
    if (asset) |val| return @ptrCast(@alignCast(val));
    return null;
}

pub fn fetch(self: *Self, comptime T: type, path: []const u8) ?*T {
    const res = self.load(T, path) catch return null;
    if (res.is_empty()) return null;
    return self.get(T, res);
}
