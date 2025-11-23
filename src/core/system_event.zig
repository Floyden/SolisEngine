const solis = @import("solis");
const c = solis.external.c;
const std = @import("std");
const Events = solis.events.Events;
const EventReader = solis.events.EventReader;
const EventWriter = solis.events.EventWriter;
const Global = solis.world.Global;
const Window = solis.Window;
const input = solis.input;

pub const SystemEvent = union {
    close_request: bool,
};

// TODO: Use World to get the EventWriter.
pub fn handleSDLEvents(allocator: Global(std.mem.Allocator), window_events: EventWriter(Window.Event), input_events: EventWriter(input.KeyEvent), system_events: EventWriter(SystemEvent)) void {
    var event: c.SDL_Event = undefined;
    while (c.SDL_PollEvent(&event)) {
        switch (event.type) {
            c.SDL_EVENT_QUIT, c.SDL_EVENT_WINDOW_CLOSE_REQUESTED => system_events.emit(allocator.get().*, .{ .close_request = true }) catch @panic("OOM?"),
            c.SDL_EVENT_WINDOW_RESIZED => window_events.emit(allocator.get().*, .{ .resized = Window.Resized{
                .window = event.window.windowID,
                .width = @intCast(event.window.data1),
                .height = @intCast(event.window.data2),
            } }) catch @panic("OOM?"),
            c.SDL_EVENT_KEY_DOWN => input_events.emit(allocator.get().*, .{
                .down = true,
                .key_code = event.key.key,
                .scan_code = event.key.scancode,
                .mod = event.key.mod,
            }) catch @panic("OOM?"),
            c.SDL_EVENT_KEY_UP => input_events.emit(allocator.get().*, .{
                .down = false,
                .key_code = event.key.key,
                .scan_code = event.key.scancode,
                .mod = event.key.mod,
            }) catch @panic("OOM?"),
            else => {},
        }
    }
}
