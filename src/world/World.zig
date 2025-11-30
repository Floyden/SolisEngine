const std = @import("std");
const ecs = @import("zflecs");
const events = @import("solis").events;

const Self = @This();
inner: *ecs.world_t,

pub fn init() Self {
    return .{
        .inner = ecs.init(),
    };
}

pub fn deinit(self: *Self) void {
    _ = ecs.fini(self.inner);
}

pub fn update(self: *Self) void {
    _ = ecs.progress(self.inner, 0);
}

pub fn register(self: *Self, T: type) void {
    ecs.COMPONENT(self.inner, T);
}

pub fn registerGlobal(self: *Self, T: type, value: T) *T {
    ecs.COMPONENT(self.inner, T);
    _ = ecs.singleton_set(self.inner, T, value);
    return ecs.singleton_get_mut(self.inner, T).?;
}

pub fn getGlobal(self: *const Self, T: type) ?*const T {
    return ecs.singleton_get(self.inner, T);
}

pub fn getGlobalMut(self: *Self, T: type) ?*T {
    return ecs.singleton_get_mut(self.inner, T);
}

pub fn newEntity(self: *Self, name: [*:0]const u8) ecs.entity_t {
    return ecs.new_entity(self.inner, name);
}

pub fn set(self: *Self, entity: ecs.entity_t, T: type, val: T) *T {
    _ = ecs.set(self.inner, entity, T, val);
    return ecs.get_mut(self.inner, entity, T).?;
}

pub fn get(self: *Self, entity: ecs.entity_t, T: type) *const T {
    return ecs.get(self.inner, entity, T).?;
}

pub fn getMut(self: *Self, entity: ecs.entity_t, T: type) *T {
    return ecs.get_mut(self.inner, entity, T).?;
}

pub fn prefab(self: *Self, name: [*:0]const u8) u64 {
    return ecs.new_prefab(self.inner, name);
}

pub fn pair(self: *Self, a: ecs.entity_t, relationship: ecs.entity_t, b: ecs.entity_t) void {
    ecs.add_pair(self.inner, a, relationship, b);
}

/// -------- Event Handling ----------------
pub fn registerEvent(self: *Self, T: type) void {
    ecs.COMPONENT(self.inner, events.Events(T));
    ecs.COMPONENT(self.inner, events.EventReader(T));
    ecs.COMPONENT(self.inner, events.EventWriter(T));
    ecs.COMPONENT(self.inner, events.EventCursor(T));
    // TODO: Add destructor for events
    _ = self.registerGlobal(events.Events(T), events.Events(T).init());
}

pub fn parseParamTuple(args: []const type) type {
    const fields = comptime blk: {
        var res: [args.len]std.builtin.Type.StructField = undefined;
        for (args, &res, 0..) |arg, *field, i| {
            field.* = .{
                .name = std.fmt.comptimePrint("{d}", .{i}),
                .type = arg,
                .default_value_ptr = null,
                .is_comptime = false,
                .alignment = @alignOf(arg),
            };
        }
        break :blk res;
    };

    return @Type(.{ .@"struct" = .{
        .layout = .auto,
        .fields = &fields,
        .decls = &.{},
        .is_tuple = true,
    } });
}

const SystemDescription = struct {
    stage: ?u64 = null,
};

// TODO: Add support for error values in systems
pub fn addSystem(self: *Self, allocator: std.mem.Allocator, system: anytype, desc: SystemDescription) !void {
    const SystemType = @TypeOf(system);
    const system_info = @typeInfo(SystemType);
    if (system_info != .@"fn") @compileError("Only Functions supported in World.addSystem");

    const params = system_info.@"fn".params;
    comptime var type_array: [params.len]type = undefined;

    // Extract paramters
    inline for (params, type_array[0..]) |param, *types| {
        if (param.type) |ptype| {
            types.* = ptype;
        } else @compileError("Parameter Type is null");
    }

    const TupleType = parseParamTuple(&type_array);
    const Context = comptime struct {
        callback: *const SystemType,
        params: TupleType,
        allocator: std.mem.Allocator,

        fn free(self_ptr_opt: ?*anyopaque) callconv(.c) void {
            if (self_ptr_opt) |self_ptr| {
                var self_ctx: *@This() = @ptrCast(@alignCast(self_ptr));
                self_ctx.allocator.destroy(self_ctx);
            }
        }

        fn invoke(iter: *ecs.iter_t) callconv(.c) void {
            const ctx_opt = iter.callback_ctx;
            if (ctx_opt) |ctx_ptr| {
                const ctx: *@This() = @ptrCast(@alignCast(ctx_ptr));
                @call(.auto, ctx.callback, ctx.params);
            }
        }
    };

    const system_entity = self.newEntity(@typeName(SystemType));

    // Create and fill parameter tuple
    const ctx: *Context = try allocator.create(Context);
    const tuple = &ctx.params;
    ctx.callback = system;
    ctx.allocator = allocator;
    inline for (params, 0..) |param, i| {
        const field_name = comptime std.fmt.comptimePrint("{}", .{i});
        if (param.type) |ptype|
            @field(tuple.*, field_name) = try ptype.init(self, system_entity);
    }

    // Query: create query_desc_t & ecs query
    var system_desc: ecs.system_desc_t = .{
        .entity = system_entity,
        .callback = Context.invoke,
        .callback_ctx = ctx,
        .callback_ctx_free = Context.free,
    };

    const system_name = comptime std.fmt.comptimePrint("{s}_system", .{@typeName(SystemType)});
    const system_stage = if (desc.stage) |stage| stage else ecs.OnUpdate;
    _ = ecs.SYSTEM(self.inner, system_name, system_stage, &system_desc);
}
