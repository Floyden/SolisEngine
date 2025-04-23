const _uuid = @import("solis").uuid;
const Uuid = _uuid.Uuid;
const type_id = @import("solis").type_id;

pub const HandleAny = struct {
    uuid: Uuid,
    typeId: type_id.TypeId,

    pub fn new(comptime T: type) HandleAny {
        return .{
            .uuid = _uuid.new(),
            .typeId = type_id.typeId(T),
        };
    }

    pub fn with_uuid(comptime T: type, uuid: Uuid) HandleAny {
        return .{
            .uuid = uuid,
            .typeId = type_id.typeId(T),
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
