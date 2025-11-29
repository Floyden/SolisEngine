const std = @import("std");
const solis = @import("solis");
const c = solis.external.c;
const World = solis.world.World;
const EventWriter = solis.events.EventWriter;
const KeyEvent = solis.input.KeyEvent;
const input = solis.input;
const Window = solis.Window;

pub const SystemEvent = union {
    close_request: bool,
};

pub fn handleSystemEvents(allocator: std.mem.Allocator, world: *World) !void {
    var system_events = try EventWriter(SystemEvent).init(world, 0);
    var window_events = try EventWriter(Window.Event).init(world, 0);
    var input_events = try EventWriter(KeyEvent).init(world, 0);
    var event: c.SDL_Event = undefined;
    while (c.SDL_PollEvent(&event)) {
        switch (event.type) {
            c.SDL_EVENT_QUIT, c.SDL_EVENT_WINDOW_CLOSE_REQUESTED => system_events.emit(allocator, .{ .close_request = true }) catch @panic("OOM?"),
            c.SDL_EVENT_WINDOW_RESIZED => try window_events.emit(allocator, .{ .resized = Window.Resized{
                .window = event.window.windowID,
                .width = @intCast(event.window.data1),
                .height = @intCast(event.window.data2),
            } }),
            c.SDL_EVENT_KEY_DOWN => input_events.emit(allocator, .{
                .down = true,
                .key_code = event.key.key,
                .scan_code = event.key.scancode,
                .mod = event.key.mod,
            }) catch @panic("OOM?"),
            c.SDL_EVENT_KEY_UP => input_events.emit(allocator, .{
                .down = false,
                .key_code = event.key.key,
                .scan_code = event.key.scancode,
                .mod = event.key.mod,
            }) catch @panic("OOM?"),
            c.SDL_EVENT_MOUSE_MOTION => {
                var writer = try EventWriter(input.MouseMotionEvent).init(world, 0);
                const motion = event.motion;
                try writer.emit(allocator, .{
                    .abs = .{ motion.x, motion.y },
                    .rel = .{ motion.xrel, motion.yrel },
                });
            },
            c.SDL_EVENT_MOUSE_BUTTON_UP, c.SDL_EVENT_MOUSE_BUTTON_DOWN => {
                var writer = try EventWriter(input.MouseButtonEvent).init(world, 0);
                const button = event.button;
                try writer.emit(allocator, .{
                    .button = button.button,
                    .down = button.down,
                    .clicks = button.clicks,
                    .pos = .{ button.x, button.y },
                });
            },
            else => {},
        }
    }
}
