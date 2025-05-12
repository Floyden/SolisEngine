const solis = @import("solis");
const typeId = solis.typeId;
const TypeId = solis.TypeId;

const Uuid = solis.Uuid;
const uuidNew = solis.uuidNew;

pub const HandleAny = struct {
    uuid: Uuid,
    typeId: TypeId,

    pub fn new(comptime T: type) HandleAny {
        return .{
            .uuid = uuidNew(),
            .typeId = typeId(T),
        };
    }

    pub fn with_uuid(comptime T: type, uuid: Uuid) HandleAny {
        return .{
            .uuid = uuid,
            .typeId = typeId(T),
        };
    }
};

pub fn Handle(comptime T: type) type {
    return struct {
        const Self = @This();
        inner: HandleAny,

        pub const empty = Self{ .inner = .with_uuid(T, 0) };

        pub fn new() Self {
            return .{
                .inner = .new(T),
            };
        }

        pub fn is_empty(self: Self) bool {
            return self.inner.uuid == 0;
        }

        pub fn uuid(self: Self) Uuid {
            return self.inner.uuid;
        }
    };
}
