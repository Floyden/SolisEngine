const std = @import("std");
const solis = @import("solis");
const Allocator = std.mem.Allocator;
const Shader = @import("Shader.zig");

const Self = @This();

pub fn import(allocator: Allocator, reader: *std.Io.Reader, meta: solis.assets.Server.ImportMeta) ?Shader {
    const code = allocator.alloc(u8, meta.length) catch @panic("OOM");
    const len = reader.readSliceShort(code) catch |e| {
        std.log.err("ShaderImporter: {}, Path: {s}", .{ e, meta.path });
        return null;
    };
    std.debug.assert(len == meta.length);

    // TODO: Call the preprocessor when implemented
    // const extension = std.fs.path.extension(meta.path);
    const stage = getShaderStage(meta.ext) orelse {
        std.log.err("ShaderImporter: Unknown extension: {s}, Path: {s}", .{ meta.ext, meta.path });
        return null;
    };

    const desc = Shader.Description{
        .code = code,
        .stage = stage,
        .source_type = Shader.SourceType.glsl,
    };

    return Shader.init(desc, allocator) catch |e| {
        std.log.err("ShaderImporter: {}, Path: {s}", .{ e, meta.path });
        return null;
    };
}

fn getShaderStage(extension: []const u8) ?Shader.Stage {
    if (std.mem.eql(u8, extension, ".vert")) {
        return Shader.Stage.Vertex;
    } else if (std.mem.eql(u8, extension, ".frag")) {
        return Shader.Stage.Fragment;
    }

    return null;
}
