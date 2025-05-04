const std = @import("std");
const vertex_data = @import("solis").vertex_data;
const spirv = @import("solis").external.spirv;

const Self = @This();

pub const Stage = enum {
    Vertex,
    Fragment,
};

pub const SourceType = enum {
    glsl,
    spirv,
};

pub const Description = struct {
    code: []const u8,
    stage: Stage,
    source_type: SourceType,
};

code: std.ArrayList(u32),
stage: Stage,
inputs: std.ArrayList(u32),
outputs: std.ArrayList(u32),
uniform_buffers: std.ArrayList(u32),
storage_buffers: std.ArrayList(u32),
storage_textures: std.ArrayList(u32),
samplers: std.ArrayList(u32),

pub fn init(desc: Description, allocator: std.mem.Allocator) !Self {
    var code = std.ArrayList(u32).init(allocator);
    switch (desc.source_type) {
        .spirv => {
            try code.appendSlice(@alignCast(@ptrCast(desc.code)));
        },
        .glsl => {
            try compileGlslShader(desc.code, desc.stage, &code);
        },
    }
    var res = Self{
        .code = code,
        .stage = desc.stage,
        .inputs = std.ArrayList(u32).init(allocator),
        .outputs = std.ArrayList(u32).init(allocator),
        .uniform_buffers = std.ArrayList(u32).init(allocator),
        .storage_buffers = std.ArrayList(u32).init(allocator),
        .storage_textures = std.ArrayList(u32).init(allocator),
        .samplers = std.ArrayList(u32).init(allocator),
    };
    res.analyze();

    return res;
}

pub fn deinit(self: *Self) void {
    self.code.deinit();
    self.inputs.deinit();
    self.outputs.deinit();
    self.uniform_buffers.deinit();
    self.storage_buffers.deinit();
    self.storage_textures.deinit();
    self.samplers.deinit();
}

// TODO:Implement a preprocessor which calls glslang_shader_preprocess to handle includes
pub fn compileGlslShader(code: []const u8, stage: Stage, destination: *std.ArrayList(u32)) !void {
    _ = spirv.glslang_initialize_process();
    defer spirv.glslang_finalize_process();

    const glslang_stage: c_uint = switch (stage) {
        .Vertex => spirv.GLSLANG_STAGE_VERTEX,
        .Fragment => spirv.GLSLANG_STAGE_FRAGMENT,
    };

    const input = spirv.glslang_input_t{
        .language = spirv.GLSLANG_SOURCE_GLSL,
        .stage = glslang_stage,
        .client = spirv.GLSLANG_CLIENT_VULKAN,
        .client_version = spirv.GLSLANG_TARGET_VULKAN_1_4,
        .target_language = spirv.GLSLANG_TARGET_SPV,
        .target_language_version = spirv.GLSLANG_TARGET_SPV_1_0,
        .code = @ptrCast(code),
        .default_version = 100,
        .default_profile = spirv.GLSLANG_NO_PROFILE,
        .force_default_version_and_profile = 0,
        .forward_compatible = 0,
        .messages = spirv.GLSLANG_MSG_DEFAULT_BIT,
        .resource = spirv.glslang_default_resource(),
    };

    const shader = spirv.glslang_shader_create(&input);

    defer spirv.glslang_shader_delete(shader);

    if (spirv.glslang_shader_preprocess(shader, &input) == 0) {
        std.log.warn("Preprocess failed", .{});
        std.log.warn("{s}", .{spirv.glslang_shader_get_info_log(shader)});
        std.log.warn("{s}", .{spirv.glslang_shader_get_info_debug_log(shader)});
        std.log.warn("{s}", .{input.code});
        return error.compileFail;
    }
    if (spirv.glslang_shader_parse(shader, &input) == 0) {
        std.log.warn("Parse failed", .{});
        std.log.warn("{s}", .{spirv.glslang_shader_get_info_log(shader)});
        std.log.warn("{s}", .{spirv.glslang_shader_get_info_debug_log(shader)});
        std.log.warn("{s}", .{spirv.glslang_shader_get_preprocessed_code(shader)});
        return error.compileFail;
    }
    const program = spirv.glslang_program_create();
    spirv.glslang_program_add_shader(program, shader);

    if (spirv.glslang_program_link(program, spirv.GLSLANG_MSG_SPV_RULES_BIT | spirv.GLSLANG_MSG_VULKAN_RULES_BIT) == 0) {
        std.log.warn("Link failed", .{});
        return error.compileFail;
    }
    spirv.glslang_program_SPIRV_generate(program, glslang_stage);
    const length = spirv.glslang_program_SPIRV_get_size(program);
    try destination.resize(length);
    spirv.glslang_program_SPIRV_get(program, @ptrCast(destination.items.ptr));
}

fn analyze(self: *Self) void {
    var context: spirv.spvc_context = undefined;
    if (spirv.spvc_context_create(&context) != 0) @panic("Fail");
    defer spirv.spvc_context_destroy(context);

    var parsed: spirv.spvc_parsed_ir = undefined;
    if (spirv.spvc_context_parse_spirv(context, self.code.items.ptr, self.code.items.len, &parsed) != 0) @panic("Fail");

    var compiler: spirv.spvc_compiler = undefined;
    if (spirv.spvc_context_create_compiler(context, spirv.SPVC_BACKEND_GLSL, parsed, spirv.SPVC_CAPTURE_MODE_TAKE_OWNERSHIP, &compiler) != 0) @panic("Fail");

    var resources: spirv.spvc_resources = undefined;
    if (spirv.spvc_compiler_create_shader_resources(compiler, &resources) != 0) @panic("Fail");

    var resource_list: [*c]const spirv.spvc_reflected_resource = undefined;
    var resource_list_size: usize = 0;

    // Input
    if (spirv.spvc_resources_get_resource_list_for_type(resources, spirv.SPVC_RESOURCE_TYPE_STAGE_INPUT, &resource_list, &resource_list_size) != 0) @panic("Fail");
    self.inputs.resize(resource_list_size) catch @panic("OOM");

    // Output
    if (spirv.spvc_resources_get_resource_list_for_type(resources, spirv.SPVC_RESOURCE_TYPE_STAGE_OUTPUT, &resource_list, &resource_list_size) != 0) @panic("Fail");
    self.outputs.resize(resource_list_size) catch @panic("OOM");

    // uniform
    if (spirv.spvc_resources_get_resource_list_for_type(resources, spirv.SPVC_RESOURCE_TYPE_UNIFORM_BUFFER, &resource_list, &resource_list_size) != 0) @panic("Fail");
    self.uniform_buffers.resize(resource_list_size) catch @panic("OOM");
    
    // storage buffers 
    if (spirv.spvc_resources_get_resource_list_for_type(resources, spirv.SPVC_RESOURCE_TYPE_STORAGE_BUFFER, &resource_list, &resource_list_size) != 0) @panic("Fail");
    self.storage_buffers.resize(resource_list_size) catch @panic("OOM");
    
    // storage buffers 
    if (spirv.spvc_resources_get_resource_list_for_type(resources, spirv.SPVC_RESOURCE_TYPE_STORAGE_IMAGE, &resource_list, &resource_list_size) != 0) @panic("Fail");
    self.storage_textures.resize(resource_list_size) catch @panic("OOM");

    // num_samplers
    if (spirv.spvc_resources_get_resource_list_for_type(resources, spirv.SPVC_RESOURCE_TYPE_SAMPLED_IMAGE, &resource_list, &resource_list_size) != 0) @panic("Fail");
    self.samplers.resize(resource_list_size) catch @panic("OOM");
}
