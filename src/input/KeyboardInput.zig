const std = @import("std");
const solis = @import("solis");
const World = solis.world.World;
const Global = solis.world.Global;
const EventReader = solis.events.EventReader;

const Self = @This();

pressed: std.AutoArrayHashMap(u32, ?void),

pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .pressed = std.AutoArrayHashMap(u32, ?void).init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    self.pressed.deinit();
}

pub fn isKeyDown(self: Self, key: u32) bool {
    return self.pressed.contains(key);
}

pub fn keyboardInputSystem(input: Global(Self), input_events: EventReader(InputEvent)) void {
    while(input_events.next()) |event| {
        switch (event) {
            .key_event => |key_event| {
                if(key_event.down) {
                    input.getMut().pressed.put(key_event.scan_code, null) catch @panic("OOM");
                } else {
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
