const std = @import("std");
const json = std.json;

const Self = @This();

accessors: []struct {
    bufferView: i32,
    byteOffset: i32,
    componentType: i32,
    count: i32,
    max: []f32,
    min: []f32,
    type: []const u8,
},

asset: struct {
    generator: []const u8,
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
images: []struct { uri: []const u8 },
materials: []struct {
    name: []const u8,
    pbrMetallicRoughness: struct {
        baseColorTexture: struct { index: i32 },
        metallicRoughnessTexture: struct { index: i32 },
    },
},
meshes: []struct {
    name: []const u8,
    primitives: []struct {
        attributes: struct {
            NORMAL: i32,
            POSITION: i32,
            TANGENT: i32,
            TEXCOORD_0: i32,
        },
        indices: i32,
        material: i32,
        mode: i32,
    },
},
nodes: []struct { mesh: i32, name: []const u8 },
samplers: []struct { name: ?[]const u8 = null },
scene: i32,
scenes: []struct { nodes: []i32 },
textures: []struct { sampler: i32, source: i32 },

pub fn parseFromSlice(allocator: std.mem.Allocator, buffer: []const u8) !json.Parsed(Self) {
    return std.json.parseFromSlice(Self, allocator, buffer, .{ .ignore_unknown_fields = true }) catch |e| return e;
}
