const std = @import("std");
const json = std.json;

const Self = @This();

const Accessor = struct {
    bufferView: ?usize = null,
    byteOffset: u32 = 0,
    componentType: ComponentType, // Requred
    normalized: bool = false,
    count: u32, // Requred
    type: []const u8, // Requred
    max: ?[]f32 = null,
    min: ?[]f32 = null,
    name: ?[]const u8 = null,
    extensions: ?[]const u8 = null, // json
    extras: ?[]const u8 = null, // TODO: should be json, could be any type actually

    // TODO: sparse implementation,

    const ComponentType = enum(u32) {
        SignedByte = 5120,
        UnsignedByte = 5121,
        SignedShort = 5122,
        UnsignedShort = 5123,
        UnsignedInt = 5125,
        Float = 5126,
    };

    pub fn componentCount(self: Accessor) ?usize {
        if (std.mem.eql(u8, self.type, "SCALAR")) {
            return 1;
        } else if (std.mem.eql(u8, self.type, "VEC2")) {
            return 2;
        } else if (std.mem.eql(u8, self.type, "VEC3")) {
            return 3;
        } else if (std.mem.eql(u8, self.type, "VEC4") or std.mem.eql(u8, self.type, "MAT2")) {
            return 4;
        } else if (std.mem.eql(u8, self.type, "MAT3")) {
            return 9;
        } else if (std.mem.eql(u8, self.type, "MAT4")) {
            return 16;
        }
        return null;
    }
};

const BufferView = struct {
    buffer: u32, // Requred
    byteLength: u32, // Requred
    byteOffset: u32 = 0,
    byteStride: ?u8 = null,
    target: ?Target = null,
    name: ?[]const u8 = null,
    extensions: ?[]const u8 = null, // json
    extras: ?[]const u8 = null, // TODO: should be json, could be any type actually

    const Target = enum(u32) {
        ArrayBuffer = 34962,
        ElementArrayBuffer = 34963,
    };
};

accessors: []Accessor,
asset: struct {
    generator: ?[]const u8 = null,
    version: []const u8,
},
bufferViews: []BufferView,
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
