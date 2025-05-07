const std = @import("std");
const json = std.json;

const zigimg = @import("zigimg");

const mesh = @import("mesh.zig");
const Mesh = @import("mesh.zig").Mesh;
const Handle = @import("assets.zig").Handle;
const AssetServer = @import("assets.zig").Server;
const Image = @import("Image.zig");
const Transformation = @import("Transformation.zig");
const Matrix4f = @import("matrix.zig").Matrix4f;
const RenderTexture = @import("renderer/texture.zig").Handle;
const PBRMaterial = @import("PBRMaterial.zig");

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

const Asset = struct {
    version: []const u8, //required
    generator: ?[]const u8 = null,
    copyright: ?[]const u8 = null,
    minVersion: ?[]const u8 = null,
    extensions: ?[]const u8 = null, // json
    extras: ?[]const u8 = null, // TODO: should be json, could be any type actually
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

const Material = struct {
    name: ?[]const u8 = null,
    extensions: json.Value = .null,
    extras: ?[]const u8 = null, // TODO: should be json, could be any type actually
    pbrMetallicRoughness: ?struct {
        baseColorFactor: [4]f32 = .{ 1.0, 1.0, 1.0, 1.0 },
        baseColorTexture: ?TextureInfo = null,
        metallicFactor: f32 = 1.0,
        roughnessFactor: f32 = 1.0,
        metallicRoughnessTexture: ?TextureInfo = null,
        extensions: ?[]const u8 = null, // json
        extras: ?[]const u8 = null, // TODO: should be json, could be any type actually
    } = null,
    normalTexture: ?struct {
        index: u32, // required
        texCoord: u32 = 0,
        scale: f32 = 1.0,
        extensions: ?[]const u8 = null, // json
        extras: ?[]const u8 = null, // TODO: should be json, could be any type actually
    } = null,
    occlusionTexture: ?struct {
        index: u32, // required
        texCoord: u32 = 0,
        strength: f32 = 1.0,
        extensions: ?[]const u8 = null, // json
        extras: ?[]const u8 = null, // TODO: should be json, could be any type actually

    } = null,
    emissiveTexture: ?TextureInfo = null,
    emissiveFactor: [3]f32 = .{ 0.0, 0.0, 0.0 },
    alphaMode: []const u8 = "OPAQUE",
    alphaCutoff: f32 = 0.5,
    doubleSided: bool = false,
};

const Node = struct {
    camera: ?u32 = null,
    children: ?[]u32 = null,
    skin: ?u32 = null,
    matrix: ?[16]f32 = null,
    mesh: ?u32 = null,
    rotation: [4]f32 = .{ 0.0, 0.0, 0.0, 1.0 },
    scale: [3]f32 = .{ 1.0, 1.0, 1.0 },
    translation: [3]f32 = .{ 0.0, 0.0, 0.0 },
    weights: ?[]f32 = null,
    name: ?[]const u8 = null,
    extensions: ?[]const u8 = null, // json
    extras: ?[]const u8 = null, // TODO: should be json, could be any type actually

    pub fn getTransform(self: Node) Transformation {
        if (self.matrix) |matrix| return Transformation.fromMatrix(Matrix4f.from(&matrix));
        return Transformation{
            .translation = .from(&self.translation),
            .rotation = .fromXYZW(self.rotation),
            .scale = .from(&self.scale),
        };
    }
};

const Texture = struct {
    sampler: ?u32 = null,
    source: ?u32 = null,
    name: ?[]const u8 = null,
    extensions: ?[]const u8 = null, // json
    extras: ?[]const u8 = null, // TODO: should be json, could be any type actually
};

const TextureInfo = struct {
    index: u32,
    texCoord: u32 = 0,
    extensions: ?[]const u8 = null, // json
    extras: ?[]const u8 = null, // TODO: should be json, could be any type actually
};

_resource_path: ?[]const u8 = null, // Relative path to load other resources if needed
_buffer: ?[]const u8 = null, // Buffer of the json file
accessors: ?[]Accessor = null,
asset: Asset,
bufferViews: ?[]BufferView = null,
buffers: ?[]struct {
    byteLength: u32,
    uri: []const u8,
} = null,
images: ?[]struct { uri: []const u8 } = null,
materials: ?[]Material = null,
meshes: ?[]struct {
    name: ?[]const u8 = null,
    primitives: []struct {
        attributes: std.json.ArrayHashMap(u32),
        indices: ?u32 = null,
        material: ?u32 = null,
        mode: Mode = .triangles,

        const Mode = enum(u8) { points, lines, line_loop, line_strip, triangles, triangle_strip, triangle_fan };
    },
} = null,
nodes: ?[]Node = null,
samplers: ?[]struct {
    name: ?[]const u8 = null,
    magFilter: ?u32 = null,
    minFilter: ?u32 = null,
    wrapS: ?u32 = null,
    wrapT: ?u32 = null,
} = null,
scene: ?i32 = null,
scenes: ?[]struct { nodes: []i32 } = null,
textures: ?[]Texture = null,

pub fn parseFromFile(allocator: std.mem.Allocator, path: []const u8) !Self {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const stat = try file.stat();
    const buffer = allocator.alloc(u8, stat.size) catch @panic("OOM");
    const count = try file.read(buffer);

    var self = try parseFromSlice(allocator, buffer[0..count]);
    self._buffer = buffer;
    self._resource_path = std.fs.path.dirname(path).?;
    return self;
}

pub fn parseFromSlice(allocator: std.mem.Allocator, buffer: []const u8) !Self {
    const res = std.json.parseFromSlice(Self, allocator, buffer, .{ .ignore_unknown_fields = true }) catch |e| return e;
    return res.value;
}

pub fn parseVertexUsage(value: []const u8) ?struct { mesh.ElementUsage, u32 } {
    if (std.mem.eql(u8, value, "POSITION")) {
        return .{ mesh.ElementUsage.position, 0 };
    } else if (std.mem.eql(u8, value, "NORMAL")) {
        return .{ mesh.ElementUsage.normal, 0 };
    } else if (std.mem.eql(u8, value, "TANGENT")) {
        return .{ mesh.ElementUsage.tangent, 0 };
    } else if (std.mem.startsWith(u8, value, "TEXCOORD_")) {
        const index = std.fmt.parseInt(u32, value[9..], 10) catch return null;
        return .{ mesh.ElementUsage.texcoord, index };
    }
    std.log.err("Unknown vertex usage: {s}", .{value});
    return null;
}

pub fn loadBufferFromFile(self: Self, allocator: std.mem.Allocator, index: usize) ![]u8 {
    // TODO: check null handles
    std.debug.assert(self._resource_path != null);
    std.debug.assert(self.buffers.?.len > index);

    const path = try std.fs.path.join(allocator, &[2][]const u8{ self._resource_path.?, self.buffers.?[index].uri });

    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const buffer = try allocator.alloc(u8, self.buffers.?[index].byteLength);
    _ = try file.readAll(buffer);
    return buffer;
}

pub fn loadImageFromFile(self: Self, index: usize, allocator: std.mem.Allocator) !Image {
    if (self.images == null) return error.NoImages;

    std.debug.assert(self._resource_path != null);
    std.debug.assert(self.images.?.len > index);

    const path = try std.fs.path.join(allocator, &[2][]const u8{ self._resource_path.?, self.images.?[index].uri });

    var image = try zigimg.Image.fromFilePath(allocator, path);
    if (image.pixelFormat() != .rgba32)
        try image.convert(.rgba32);

    const res = Image.init_fill(
        image.rawBytes(),
        .{ .width = @intCast(image.width), .height = @intCast(image.height) },
        Image.TextureFormat.fromPixelFormat(image.pixelFormat()),
        allocator,
    );
    return res;
}

pub fn loadImage(self: Self, index: usize, asset_server: *AssetServer) !Handle(Image) {
    if (self.images == null) return error.NoImages;

    std.debug.assert(self._resource_path != null);
    std.debug.assert(self.images.?.len > index);

    const path = try std.fs.path.join(asset_server.allocator, &[2][]const u8{ self._resource_path.?, self.images.?[index].uri });
    const handle = try asset_server.load(Image, path);

    return handle;
}

pub fn loadBaseColorImage(self: Self, asset_server: *AssetServer, mat_idx: u32) !?Handle(Image) {
    if (self.materials) |materials| {
        std.debug.assert(materials.len > mat_idx);
        if (materials[mat_idx].pbrMetallicRoughness) |pbr|
            if (pbr.baseColorTexture) |texture|
                return try loadImage(self, texture.index, asset_server);
    }
    return null;
}

pub fn loadNormalImage(self: Self, asset_server: *AssetServer, mat_idx: u32) !?Handle(Image) {
    if (self.materials) |materials| {
        std.debug.assert(materials.len > mat_idx);
        if (materials[mat_idx].normalTexture) |normal|
            return try loadImage(self, normal.index, asset_server);
    }
    return null;
}

pub fn loadMetalRoughImage(self: Self, asset_server: *AssetServer, mat_idx: u32) !?Handle(Image) {
    if (self.materials) |materials| {
        std.debug.assert(materials.len > mat_idx);
        if (materials[mat_idx].pbrMetallicRoughness) |pbr|
            if (pbr.metallicRoughnessTexture) |texture|
                return try loadImage(self, texture.index, asset_server);
    }
    return null;
}

pub fn parseMaterials(self: Self, allocator: std.mem.Allocator, textures: []const RenderTexture) !std.ArrayList(PBRMaterial) {
    var materials = std.ArrayList(PBRMaterial).init(allocator);
    errdefer materials.deinit();

    if (self.materials == null) return materials;

    for (self.materials.?) |mat| {
        const material = try materials.addOne();
        material.* = PBRMaterial{};
        if (mat.pbrMetallicRoughness) |pbr| {
            material.*.base_color = pbr.baseColorFactor;
            material.*.base_color_texture = if (pbr.baseColorTexture) |idx| textures[idx.index] else null;
            material.*.metallic_roughness_texture = if (pbr.metallicRoughnessTexture) |idx| textures[idx.index] else null;
            material.*.roughness = pbr.roughnessFactor;
            material.*.metallic = pbr.metallicFactor;
        }
        material.*.normal_texture = if (mat.normalTexture) |idx| textures[idx.index] else null;
    }

    return materials;
}

pub fn parseMeshes(self: Self, allocator: std.mem.Allocator) !std.ArrayList(Mesh) {
    var meshes = std.ArrayList(Mesh).init(allocator);
    errdefer meshes.deinit();

    if (self.meshes == null) return meshes;

    for (0..self.meshes.?.len) |i| try meshes.append(try self.parseMeshData(i, allocator));
    return meshes;
}

pub fn parseMeshData(self: Self, mesh_index: usize, allocator: std.mem.Allocator) !Mesh {
    // TODO: check null handles
    const attributes = &self.meshes.?[mesh_index].primitives[0].attributes.map;
    var mesh_res = Mesh.init(allocator);

    var num_vertices: ?u32 = null;
    const buffer_offsets: []u32 = allocator.alloc(u32, attributes.count()) catch @panic("OOM");
    for (attributes.keys(), buffer_offsets) |attr_key, *offset| {
        const accessor = self.accessors.?[attributes.get(attr_key).?];
        var element_desc: mesh.ElementDesc = undefined;
        const view = self.bufferViews.?[accessor.bufferView.?];
        // TODO: This is probably really hacky and only works if the entire mesh uses one buffer
        offset.* = accessor.byteOffset + view.byteOffset;
        element_desc.type = blk: switch (accessor.componentType) {
            .Float => {
                switch (accessor.componentCount().?) {
                    1 => break :blk mesh.ElementType.float1,
                    2 => break :blk mesh.ElementType.float2,
                    3 => break :blk mesh.ElementType.float3,
                    4 => break :blk mesh.ElementType.float4,
                    else => return error.InvalidMesh,
                }
            },
            else => return error.InvalidMesh,
        };
        const usage = parseVertexUsage(attr_key) orelse return error.InvalidMesh;
        element_desc.usage = usage[0];
        element_desc.index = usage[1];
        num_vertices = accessor.count;

        mesh_res.vertex_description.append(element_desc) catch @panic("OOM");
    }
    if (num_vertices == null) return error.NoVertices;
    mesh_res.num_vertices = num_vertices.?;

    const indices_opt = self.meshes.?[mesh_index].primitives[0].indices;
    var index_buffer_opt: ?Mesh.IndexBuffer = null;
    if (indices_opt) |indices| {
        const accessor = self.accessors.?[indices];
        if (accessor.bufferView == null)
            return error.NotImplemented;

        if (!std.mem.eql(u8, accessor.type, "SCALAR"))
            return error.WrongType;

        const length = accessor.count;

        switch (accessor.componentType) {
            .UnsignedByte => index_buffer_opt = .{ .byte = allocator.alloc(u8, length) catch @panic("OOM") },
            .UnsignedShort => index_buffer_opt = .{ .short = allocator.alloc(u16, length) catch @panic("OOM") },
            .UnsignedInt => index_buffer_opt = .{ .int = allocator.alloc(u32, length) catch @panic("OOM") },
            else => return error.WrongType,
        }
    }

    // TODO: This will not work for when the buffers are split up in multiple files and in several other cases
    const buffer_view_index = self.meshes.?[mesh_index].primitives[0].attributes.map.values()[0];
    const buffer_index = self.bufferViews.?[buffer_view_index].buffer;

    const uri = self.buffers.?[buffer_index].uri;
    const DATA_PREFIX = "data:application/octet-stream;base64,";
    if (!std.mem.startsWith(u8, uri, DATA_PREFIX)) {
        const data = try self.loadBufferFromFile(allocator, 0);
        mesh_res.data = allocator.alloc(u8, data.len) catch @panic("OOM");
        var vertex_size: usize = 0;
        for (mesh_res.vertex_description.items) |desc| {
            vertex_size += desc.type.size();
        }

        var vertex_offset: u32 = 0;
        for (mesh_res.vertex_description.items, buffer_offsets) |*desc, offset| {
            const elem_size = desc.type.size();
            desc.offset = vertex_offset;
            defer vertex_offset += elem_size;

            for (0..num_vertices.?) |i| {
                const dst_start = i * vertex_size + vertex_offset;
                const src_start = offset + i * elem_size;

                @memcpy(mesh_res.data.?[dst_start .. dst_start + elem_size], data[src_start .. src_start + elem_size]);
            }
        }

        if (index_buffer_opt) |index_buffer| {
            const view = self.bufferViews.?[self.accessors.?[indices_opt.?].bufferView.?];
            switch (index_buffer) {
                .byte => @memcpy(index_buffer.byte, data[view.byteOffset .. view.byteOffset + view.byteLength]),
                .short => @memcpy(@as([]u8, @ptrCast(index_buffer.short)), data[view.byteOffset .. view.byteOffset + view.byteLength]),
                .int => @memcpy(@as([]u8, @ptrCast(index_buffer.int)), data[view.byteOffset .. view.byteOffset + view.byteLength]),
            }
            mesh_res.index_buffer = index_buffer;
        }

        const target_desc = [_]mesh.ElementDesc{
            .{ .usage = .position, .type = .float3, .offset = 0, .index = 0 },
            .{ .usage = .color, .type = .float3, .offset = 3 * @sizeOf(f32), .index = 0 },
            .{ .usage = .normal, .type = .float3, .offset = 6 * @sizeOf(f32), .index = 0 },
            .{ .usage = .texcoord, .type = .float2, .offset = 9 * @sizeOf(f32), .index = 0 },
            .{ .usage = .tangent, .type = .float4, .offset = 11 * @sizeOf(f32), .index = 0 },
        };
        try mesh_res.rearrange(&target_desc);

        return mesh_res;
    }

    return error.e;
    //
    // _ = std.base64.standard.Decoder.decode(buffer, uri[DATA_PREFIX.len..]) catch @panic("Fail");
    // for (self.accessors) |accessor| {
    //     if (accessor.bufferView == null) return;
    //     const view = self.bufferViews[accessor.bufferView.?];
    //     switch (accessor.componentType) {
    //         Accessor.ComponentType.UnsignedShort => {
    //             const end = view.byteOffset + view.byteLength;
    //             std.log.info("{any}", .{@as([]u16, @alignCast(@ptrCast(buffer[view.byteOffset..end])))});
    //         },
    //         Accessor.ComponentType.Float => {
    //             const end = view.byteOffset + view.byteLength;
    //             std.log.info("{any}", .{@as([]f32, @alignCast(@ptrCast(buffer[view.byteOffset..end])))});
    //         },
    //         else => {},
    //     }
    //     std.log.info("{any} {any}", .{ accessor, accessor.componentCount() });
    //     std.log.info("{any}", .{view});
    // }

    // std.log.info("{any}", .{@as([]const u16, @alignCast(@ptrCast(buffer)))});
    // std.log.info("{any}", .{@as([]const f32, @alignCast(@ptrCast(buffer)))});
    // std.log.info("{any}", .{self.buffers[index].byteLength});
}
