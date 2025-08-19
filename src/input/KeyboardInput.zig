const std = @import("std");
const solis = @import("solis");
const World = solis.world.World;
const Global = solis.world.Global;
const EventReader = solis.events.EventReader;

const Self = @This();

pressed: std.AutoArrayHashMap(u32, ?void),
just_pressed: std.AutoArrayHashMap(u32, ?void),
just_released: std.AutoArrayHashMap(u32, ?void),

pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .pressed = std.AutoArrayHashMap(u32, ?void).init(allocator),
        .just_pressed = std.AutoArrayHashMap(u32, ?void).init(allocator),
        .just_released = std.AutoArrayHashMap(u32, ?void).init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    self.pressed.deinit();
}

pub fn isKeyPressed(self: Self, key: u32) bool {
    return self.pressed.contains(key);
}

pub fn isKeyJustPressed(self: Self, key: u32) bool {
    return self.just_pressed.contains(key);
}

pub fn isKeyJustReleased(self: Self, key: u32) bool {
    return self.just_released.contains(key);
}

pub fn keyboardInputSystem(input: Global(Self), input_events: EventReader(InputEvent)) void {
    input.getMut().just_pressed.clearRetainingCapacity();
    input.getMut().just_released.clearRetainingCapacity();
    while (input_events.next()) |event| {
        switch (event) {
            .key_event => |key_event| {
                if (key_event.down) {
                    if (!input.get().pressed.contains(key_event.scan_code)) {
                        input.getMut().just_pressed.put(key_event.scan_code, null) catch @panic("OOM");
                    }
                    input.getMut().pressed.put(key_event.scan_code, null) catch @panic("OOM");
                } else {
                    if (input.get().pressed.contains(key_event.scan_code)) {
                        input.getMut().just_released.put(key_event.scan_code, null) catch @panic("OOM");
                    }
                    _ = input.getMut().pressed.swapRemove(key_event.scan_code);
                }
            },
        }
    }
}

pub const InputEvent = union(enum) {
    key_event: KeyEvent,

    pub const KeyEvent = struct {
        down: bool,
        key_code: u32,
        scan_code: u32,
        mod: u32,
    };
};
