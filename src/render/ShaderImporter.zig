const std = @import("std");
const Allocator = std.mem.Allocator;
const Shader = @import("Shader.zig");

const Self = @This();

pub fn import(allocator: Allocator, path: []const u8) ?Shader {
    const file = std.fs.cwd().openFile(path, .{}) catch |e| {
        std.log.err("ShaderImporter: {?}, Path: {s}", .{ e, path });
        return null;
    };
    defer file.close();

    const stat = file.stat() catch |e| {
        std.log.err("ShaderImporter: {?}, Path: {s}", .{ e, path });
        return null;
    };
    const code = file.readToEndAlloc(allocator, stat.size) catch |e| {
        std.log.err("ShaderImporter: {?}, Path: {s}", .{ e, path });
        return null;
    };

    // TODO: Call the preprocessor when implemented
    const extension = std.fs.path.extension(path);
    const stage = getShaderStage(extension) orelse {
        std.log.err("ShaderImporter: Unknown extension: {s}, Path: {s}", .{ extension, path });
        return null;
    };

    const desc = Shader.Description{
        .code = code,
        .stage = stage,
        .source_type = Shader.SourceType.glsl,
    };

    return Shader.init(desc, allocator) catch |e| {
        std.log.err("ShaderImporter: {?}, Path: {s}", .{ e, path });
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
