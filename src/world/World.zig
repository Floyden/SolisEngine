const std = @import("std");
const ecs = @import("zflecs");
const events = @import("solis").events;

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
    ecs.COMPONENT(self.inner, events.EventWriter(T));
    // TODO: Add destructor for events
    _ = self.setSingleton(events.Events(T), events.Events(T).init(self.allocator));
}

pub fn getEventReader(self: *Self, T: type) ?events.EventReader(T) {
    const queue = self.getSingleton(events.Events(T)) orelse return null;
    return events.EventReader(T).create(queue);
}

pub fn getEventWriter(self: *Self, T: type) ?events.EventWriter(T) {
    const queue = self.getSingletonMut(events.Events(T)) orelse return null;
    return events.EventWriter(T).create(queue);
}

pub fn addSystem(self: *Self, system: anytype) void {
    const SystemType = @TypeOf(system);
    const systemInfo = @typeInfo(SystemType);
    if(systemInfo != .@"fn") @compileError("Only Functions supported in World.addSystem");

    const params = systemInfo.@"fn".params;
    inline for (params) |param| {
        if(param.type) |ptype| {
            if(ptype.WorldParameter == events.EventReader) {
                const queue = self.getSingleton(events.Events(ptype.EventType));
                std.log.debug("Reader {?}", .{queue});
            } else if(ptype.WorldParameter == events.EventWriter) {
                std.log.debug("Writer", .{});
            }
        }
    }
    // Extract paramters
    // Query: create query_desc_t & ecs query
    //
}

