const std = @import("std");
const json = std.json;

const Self = @This();

const Accessor = struct {
    bufferView: i32,
    byteOffset: i32,
    componentType: ComponentType,
    count: i32,
    max: []f32,
    min: []f32,
    type: []const u8,

    const ComponentType = enum(u32) {
        SignedByte = 5120,
        UnsignedByte = 5121,
        SignedShort = 5122,
        UnsignedShort = 5123,
        UnsignedInt = 5125,
        Float = 5126,
    };
};

accessors: []Accessor,
asset: struct {
    generator: ?[]const u8 = null,
    version: []const u8,
},
bufferViews: []struct {
    buffer: i32,
    byteLength: i32,
    byteOffset: i32,
    target: i32,
},
buffers: []struct {
    byteLength: i32,
    uri: []const u8,
},
images: ?[]struct { uri: []const u8 } = null,
materials: ?[]struct {
    name: []const u8,
    pbrMetallicRoughness: struct {
        baseColorTexture: struct { index: i32 },
        metallicRoughnessTexture: struct { index: i32 },
    },
} = null,
meshes: []struct {
    name: ?[]const u8 = null,
    primitives: []struct {
        attributes: struct {
            NORMAL: ?i32 = null,
            POSITION: ?i32 = null,
            TANGENT: ?i32 = null,
            TEXCOORD_0: ?i32 = null,
        },
        indices: ?i32 = null,
        material: ?i32 = null,
        mode: ?i32 = null,
    },
},
nodes: []struct { mesh: i32, name: ?[]const u8 = null },
samplers: ?[]struct { name: ?[]const u8 = null } = null,
scene: i32,
scenes: []struct { nodes: []i32 },
textures: ?[]struct { sampler: i32, source: i32 } = null,

pub fn parseFromSlice(allocator: std.mem.Allocator, buffer: []const u8) !Self {
    const res = std.json.parseFromSlice(Self, allocator, buffer, .{ .ignore_unknown_fields = true }) catch |e| return e;
    return res.value;

}
