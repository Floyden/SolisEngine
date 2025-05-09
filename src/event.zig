const std = @import("std");

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

        pub fn reader(self: *Self) EventReader(Event) {
            return EventReader(Event).create(self);
        }

        pub fn update(self: *Self) void {
            self.old.clearRetainingCapacity();
            std.mem.swap(std.ArrayList(Event), &self.old, &self.current);
        }
    };
}

pub fn EventReader(comptime Event: type) type {
    return struct {
        const Self = @This();
        events: *const Events(Event),
        next_event: usize,
        
        pub fn create(events: *const Events(Event)) Self {
            return .{ 
                .events = events, 
                .next_event = 0,
            };
        }

        pub fn next(self: *Self) ?Event {
            const latest = self.events.next_id;
            if(self.next_event >= latest) return null; // no new events
            if(self.events.current.items.len == 0 and self.events.old.items.len == 0) return null; // no events at all

            const current_base = latest - self.events.current.items.len;
            const old_base = current_base - self.events.old.items.len;
            defer self.next_event += 1;
            if(current_base <= self.next_event) { // next event is a current event
                return self.events.current.items[self.next_event - current_base];
            } else if(old_base <= self.next_event) { // next event is an old event
                return self.events.old.items[self.next_event - old_base];
            } else { // has not been called for a while, refresh indices
                self.next_event = old_base;
                if(self.events.old.items.len > 0) {
                    return self.events.old.items[0];
                } else 
                    return self.events.current.items[0];
            }
        }

        pub fn reset(self: *Self) void {
            self.next_event = self.events.next_id - self.events.current.items.len - self.events.old.items.len;
        }
    };
}

test "Basic Events" {
    const allocator = std.testing.allocator;
    const TestEvent = struct { id: usize };

    var events = Events(TestEvent).init(allocator);
    defer events.deinit();

    var reader = events.reader();

    try events.emit(.{.id = 1 });
    try events.emit(.{.id = 2 });
    events.update();
    try events.emit(.{.id = 3 });


    try std.testing.expectEqual(@as(?usize, 1), reader.next().?.id);
    try std.testing.expectEqual(@as(?usize, 2), reader.next().?.id);
    try std.testing.expectEqual(@as(?usize, 3), reader.next().?.id);
    try std.testing.expectEqual(@as(?TestEvent, null), reader.next());
   
    reader.reset();
    events.update();
    try events.emit(.{.id = 4 });
    
    try std.testing.expectEqual(@as(?usize, 3), reader.next().?.id);
    try std.testing.expectEqual(@as(?usize, 4), reader.next().?.id);
    try std.testing.expectEqual(@as(?TestEvent, null), reader.next());
}
