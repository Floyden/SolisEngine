const World = @import("World.zig");
const ecs = @import("zflecs");
const std = @import("std");

fn parseTupleTypes(comptime tuple: anytype) [@typeInfo(@TypeOf(tuple)).@"struct".fields.len]type {
    const TupleType = @TypeOf(tuple);
    const type_info = @typeInfo(TupleType);

    const fields = type_info.@"struct".fields;
    const type_array: [fields.len]type = comptime blk: {
        var res: [fields.len]type = undefined;
        for (&res, 0..) |*dst, i| {
            const field_name = std.fmt.comptimePrint("{}", .{i});
            dst.* = @field(tuple, field_name);
        }
        break :blk res;
    };
    return type_array;
}

fn TupleSlice(args: []const type) type {
    const fields = comptime blk: {
        var res: [args.len]std.builtin.Type.StructField = undefined;
        for (args, &res, 0..) |arg, *field, i| {
            field.* = .{
                .name = std.fmt.comptimePrint("{d}", .{i}),
                .type = ?[]arg,
                .default_value_ptr = null,
                .is_comptime = false,
                .alignment = @alignOf(?[]arg),
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

// TODO: Ensure that QueryIter does not have to be deinitialized manually
pub fn QueryIter(comptime Types: []const type) type {
    return struct {
        const Self = @This();
        pub const TypeTuple = TupleSlice(Types);
        inner: ecs.iter_t,

        pub fn next(self: *Self) ?TypeTuple {
            if (!ecs.iter_next(&self.inner)) return null;
            var res: TypeTuple = undefined;
            inline for (Types, 0..) |T, i| {
                const field_name = std.fmt.comptimePrint("{}", .{i});
                @field(res, field_name) = ecs.field(&self.inner, T, i);
            }
            return res;
        }
        pub fn deinit(self: *Self) void {
            ecs.iter_fini(&self.inner);
        }
    };
}

pub fn Query(comptime tuple: anytype) type {
    return struct {
        const Self = @This();
        const TupleArray = parseTupleTypes(tuple);
        const TupleType = World.parseParamTuple(&TupleArray);

        inner: *ecs.query_t,
        world: *World,

        pub fn init(world: *World, entity: u64) !Self {
            var desc = ecs.query_desc_t{
                .entity = entity,
            };
            inline for (TupleArray, 0..) |T, i| {
                desc.terms[i] = .{ .id = ecs.id(T) };
            }

            return .{ .inner = try ecs.query_init(world.inner, &desc), .world = world };
        }

        /// The iter needs to be deinitialized if not exhausted.
        pub fn iter(self: Self) QueryIter(&TupleArray) {
            return QueryIter(&TupleArray){ .inner = ecs.query_iter(self.world.inner, self.inner) };
        }
    };
}
