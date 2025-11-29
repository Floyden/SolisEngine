pub const KeyboardInput = @import("input/KeyboardInput.zig");
pub const KeyEvent = KeyboardInput.KeyEvent;
pub const keyboardInputSystem = KeyboardInput.keyboardInputSystem;

pub const MouseInput = @import("input/MouseInput.zig");
pub const MouseMotionEvent = MouseInput.MouseMotion;
pub const MouseButtonEvent = MouseInput.MouseButton;

const World = @import("world.zig").World;
const std = @import("std");
const ecs = @import("solis").ecs;

pub fn initModule(allocator: std.mem.Allocator, world: *World) !void {
    _ = world.registerGlobal(KeyboardInput, .init(allocator));
    world.registerEvent(KeyEvent);
    world.registerEvent(MouseMotionEvent);
    world.registerEvent(MouseButtonEvent);

    try world.addSystem(allocator, keyboardInputSystem, .{ .stage = ecs.PreUpdate });
}
