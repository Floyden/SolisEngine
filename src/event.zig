const std = @import("std");
const World = @import("solis").world.World;

pub fn Events(comptime Event: type) type {
    return struct {
        const Self = @This();

        next_id: usize,
        current: std.ArrayList(Event),
        old: std.ArrayList(Event),

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .next_id = 0,
                .current = std.ArrayList(Event).init(allocator),
                .old = std.ArrayList(Event).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.current.deinit();
            self.old.deinit();
        }

        // TODO: Replace with a writer
        pub fn emit(self: *Self, event: Event) !void {
            self.next_id += 1;
            try self.current.append(event);
        }

        pub fn writer(self: *Self) EventWriter(Event) {
            return EventWriter(Event).create(self);
        }

        pub fn update(self: *Self) void {
            self.old.clearRetainingCapacity();
            std.mem.swap(std.ArrayList(Event), &self.old, &self.current);
        }
    };
}

// Wrapper around index for storing it in the ECS
pub fn EventCursor(comptime T: type) type {
    _ = T;
    return struct { index: usize = 0 };
}

pub fn EventReader(comptime T: type) type {
    return struct {
        pub const WorldParameter = EventReader;
        pub const EventType = T;
        const Self = @This();
        events: *const Events(EventType),
        cursor: *EventCursor(T),

        pub fn init(world: *World, entity: u64) !Self {
            const events_opt = world.getGlobal(Events(EventType));

            if(events_opt) |events| {
                const cursor = world.set(entity, EventCursor(T), .{});
                return Self {
                    .events = events,
                    .cursor = cursor,
                };
            }
            std.debug.panic("Event ({?}) not initialized ", .{EventType});
        }

        pub fn next(self: Self) ?EventType {
            const latest = self.events.next_id;
            if (self.cursor.index >= latest) return null; // no new events
            if (self.events.current.items.len == 0 and self.events.old.items.len == 0) return null; // no events at all

            const current_base = latest - self.events.current.items.len;
            const old_base = current_base - self.events.old.items.len;
            defer self.cursor.index += 1;
            if (current_base <= self.cursor.index) { // next event is a current event
                return self.events.current.items[self.cursor.index - current_base];
            } else if (old_base <= self.cursor.index) { // next event is an old event
                return self.events.old.items[self.cursor.index - old_base];
            } else { // has not been called for a while, refresh indices
                self.cursor.index = old_base;
                if (self.events.old.items.len > 0) {
                    return self.events.old.items[0];
                } else return self.events.current.items[0];
            }
        }

        pub fn reset(self: *Self) void {
            self.cursor.index = self.events.next_id - self.events.current.items.len - self.events.old.items.len;
        }
    };
}

pub fn EventWriter(comptime T: type) type {
    return struct {
        pub const WorldParameter = EventWriter;
        pub const EventType = T;
        const Self = @This();
        events: *Events(EventType),

        pub fn init(world: *World, _: u64) !Self {
            const events_opt = world.getGlobalMut(Events(EventType));

            if(events_opt) |events| {
                return Self {
                    .events = events,
                };
            }
            std.debug.panic("Event ({?}) not initialized ", .{EventType});
        }

        pub fn emit(self: Self, event: EventType) !void {
            try self.events.emit(event);
        }
    };
}

test "Basic Events" {
    const allocator = std.testing.allocator;
    const TestEvent = struct { id: usize };

    var events = Events(TestEvent).init(allocator);
    defer events.deinit();

    var cursor = EventCursor(TestEvent) {};
    var reader = EventReader(TestEvent){
        .events = &events,
        .cursor = &cursor,
    };
    var writer = events.writer();

    try writer.emit(.{ .id = 1 });
    try writer.emit(.{ .id = 2 });
    events.update();
    try writer.emit(.{ .id = 3 });

    try std.testing.expectEqual(@as(?usize, 1), reader.next().?.id);
    try std.testing.expectEqual(@as(?usize, 2), reader.next().?.id);
    try std.testing.expectEqual(@as(?usize, 3), reader.next().?.id);
    try std.testing.expectEqual(@as(?TestEvent, null), reader.next());

    reader.reset();
    events.update();
    try writer.emit(.{ .id = 4 });

    try std.testing.expectEqual(@as(?usize, 3), reader.next().?.id);
    try std.testing.expectEqual(@as(?usize, 4), reader.next().?.id);
    try std.testing.expectEqual(@as(?TestEvent, null), reader.next());
}
