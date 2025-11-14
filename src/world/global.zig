const World = @import("World.zig");
const std = @import("std");

/// Wrapper of global values / singletons in the ECS. This enables us to pass Global(type) as parameter in systems.
pub fn Global(T: type) type {
    return struct {
        const Self = @This();
        world: *World,
        value: *T,
        pub fn init(world: *World, _: u64) !Self {
            return .{
                .world = world,
                .value = world.getGlobalMut(T) orelse std.debug.panic("Unregistered Type ({})", .{T}),
            };
        }

        pub fn get(self: Self) *const T {
            return self.value;
        }

        pub fn getMut(self: Self) *T {
            return self.value;
        }
    };
}
