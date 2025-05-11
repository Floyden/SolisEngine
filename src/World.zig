const std = @import("std");
const ecs = @import("zflecs");
const events = @import("event.zig");


const Self = @This();
inner : *ecs.world_t,
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .inner = ecs.init(),
        .allocator = allocator,
    };
}

pub fn deinit(self: *Self) void {
    _ = ecs.fini(self.inner);
}

pub fn register(self: *Self, T: type) void {
    ecs.COMPONENT(self.inner, T);
}

pub fn setSingleton(self: *Self, T: type, value: T) *T {
    _ = ecs.singleton_set(self.inner, T, value);
    return ecs.singleton_get_mut(self.inner, T).?;
}

pub fn getSingleton(self: *const Self, T: type) ?*const T {
    return ecs.singleton_get(self.inner, T);
}

pub fn getSingletonMut(self: *Self, T: type) ?*T {
    return ecs.singleton_get_mut(self.inner, T);
}

pub fn newEntity(self: *Self, name: [*:0]const u8) ecs.entity_t {
    return ecs.new_entity(self.inner, name);
}

pub fn set(self: *Self, entity: ecs.entity_t, T: type, val: T) *T {
    _ = ecs.set(self.inner, entity, T, val);
    return ecs.get_mut(self.inner, entity, T).?;
}

/// -------- Event Handling ----------------

pub fn registerEvent(self: *Self, T: type) void {
    ecs.COMPONENT(self.inner, events.Events(T));
    ecs.COMPONENT(self.inner, events.EventReader(T));
    // TODO: EventWriter
    // TODO: Add destructor for events
    _ = self.setSingleton(events.Events(T), events.Events(T).init(self.allocator));
}

pub fn getEventReader(self: *Self, T: type) ?events.EventReader(T) {
    const queue = self.getSingleton(events.Events(T)) orelse return null;
    return events.EventReader(T).create(queue);
}
