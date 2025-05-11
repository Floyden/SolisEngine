const ecs = @import("zflecs");


const Self = @This();
inner : *ecs.world_t,

pub fn init() Self {
    return .{
        .inner = ecs.init(),
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

pub fn newEntity(self: *Self, name: [*:0]const u8) ecs.entity_t {
    return ecs.new_entity(self.inner, name);
}

pub fn set(self: *Self, entity: ecs.entity_t, T: type, val: T) *T {
    _ = ecs.set(self.inner, entity, T, val);
    return ecs.get_mut(self.inner, entity, T).?;
}
