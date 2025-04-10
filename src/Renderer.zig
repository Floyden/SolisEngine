const std = @import("std");
const Window = @import("Window.zig");
const CommandBuffer = @import("CommandBuffer.zig");
const SDL_ERROR = Window.SDL_ERROR;
const Image = @import("Image.zig");
pub const PixelFormat = @import("zigimg").PixelFormat;
const c = @import("solis").external.c;
const spirv = @import("solis").external.spirv;
pub const sampler = @import("renderer/sampler.zig");
pub const texture = @import("renderer/texture.zig");

const Renderer = @This();
window: *Window,
device: ?*c.SDL_GPUDevice,
sample_count: c.SDL_GPUSampleCount,
pipeline: ?*c.SDL_GPUGraphicsPipeline,

pub fn init(window: *Window) !Renderer {
    // GPU Device init
    const device = c.SDL_CreateGPUDevice(c.SDL_GPU_SHADERFORMAT_SPIRV, true, null) orelse return SDL_ERROR.Fail;
    if (!c.SDL_ClaimWindowForGPUDevice(device, window.handle)) return SDL_ERROR.Fail;

    // Shaders, Can be destroyed after pipeline is created
    const v_shader = loadGlslShader(device, c.VERTEX_SHADER, "Simple Vertex", c.SDL_GPU_SHADERSTAGE_VERTEX) catch |e| return e;
    defer c.SDL_ReleaseGPUShader(device, v_shader);
    const f_shader = loadGlslShader(device, c.FRAGMENT_SHADER, "Simple Fragment", c.SDL_GPU_SHADERSTAGE_FRAGMENT) catch |e| return e;
    defer c.SDL_ReleaseGPUShader(device, f_shader);

    const sample_count: c.SDL_GPUSampleCount = c.SDL_GPU_SAMPLECOUNT_1;

    // Graphics Pipeline
    const color_target_desc = std.mem.zeroInit(c.SDL_GPUColorTargetDescription, .{ .format = c.SDL_GetGPUSwapchainTextureFormat(device, window.handle) });

    const vertex_buffer_desc = std.mem.zeroInit(c.SDL_GPUVertexBufferDescription, .{
        .slot = 0,
        .input_rate = c.SDL_GPU_VERTEXINPUTRATE_VERTEX,
        .instance_step_rate = 0,
        .pitch = @sizeOf(f32) * 11,
    });

    const vertex_attributes = [_]c.SDL_GPUVertexAttribute{
        std.mem.zeroInit(c.SDL_GPUVertexAttribute, .{
            .buffer_slot = 0,
            .format = c.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3,
            .location = 0,
            .offset = 0,
        }),
        std.mem.zeroInit(c.SDL_GPUVertexAttribute, .{
            .buffer_slot = 0,
            .format = c.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3,
            .location = 1,
            .offset = @sizeOf(f32) * 3,
        }),
        std.mem.zeroInit(c.SDL_GPUVertexAttribute, .{
            .buffer_slot = 0,
            .format = c.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3,
            .location = 2,
            .offset = @sizeOf(f32) * 3 * 2,
        }),
        std.mem.zeroInit(c.SDL_GPUVertexAttribute, .{
            .buffer_slot = 0,
            .format = c.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2,
            .location = 3,
            .offset = @sizeOf(f32) * 3 * 3,
        }),
    };

    const pipelinedesc = std.mem.zeroInit(c.SDL_GPUGraphicsPipelineCreateInfo, .{
        .target_info = .{
            .num_color_targets = 1,
            .color_target_descriptions = &color_target_desc,
            .depth_stencil_format = c.SDL_GPU_TEXTUREFORMAT_D16_UNORM,
            .has_depth_stencil_target = true,
        },

        .depth_stencil_state = .{
            .enable_depth_test = true,
            .enable_depth_write = true,
            .compare_op = c.SDL_GPU_COMPAREOP_LESS_OR_EQUAL,
        },

        .multisample_state = .{ .sample_count = sample_count },
        .primitive_type = c.SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,

        .vertex_shader = v_shader,
        .fragment_shader = f_shader,

        .vertex_input_state = .{
            .num_vertex_buffers = 1,
            .vertex_buffer_descriptions = &vertex_buffer_desc,
            .num_vertex_attributes = vertex_attributes.len,
            .vertex_attributes = &vertex_attributes,
        },
        .rasterizer_state = .{
            .cull_mode = c.SDL_GPU_CULLMODE_FRONT,
            .front_face = c.SDL_GPU_FRONTFACE_COUNTER_CLOCKWISE,
        },
        .props = 0,
    });
    const pipeline = c.SDL_CreateGPUGraphicsPipeline(device, &pipelinedesc);
    if (pipeline == null) return SDL_ERROR.Fail;
    return .{ .window = window, .device = device, .sample_count = sample_count, .pipeline = pipeline };
}

pub fn deinit(self: *Renderer) void {
    if (self.device == null) return;

    if (self.pipeline) |_| {
        c.SDL_ReleaseGPUGraphicsPipeline(self.device, self.pipeline);

        self.pipeline = null;
    }
    c.SDL_DestroyGPUDevice(self.device);
    self.device = null;
}

pub fn createTextureFromImage(self: *Renderer, image: Image) !texture.Handle {
    return self.createTextureWithData(
    .{
        .extent = image.extent,
        .format = image.format,
        .usage = c.SDL_GPU_TEXTUREUSAGE_SAMPLER,

    }, image.rawBytes());
}

pub fn createTextureWithData(self: *Renderer, desc: texture.Description, data: []const u8) !texture.Handle {
    const handle = try self.createTexture(desc);

    // Transfer image data
    {
        const buf_transfer = self.createTransferBufferNamed(@intCast(data.len), c.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD, "TexTransferBuffer") catch |e| return e;
        defer self.releaseTransferBuffer(buf_transfer);

        self.copyToTransferBuffer(buf_transfer, data);

        var cmd = self.acquireCommandBuffer() orelse return SDL_ERROR.Fail;
        defer cmd.submit();

        cmd.beginCopyPass();
        const source = c.SDL_GPUTextureTransferInfo{
            .transfer_buffer = buf_transfer,
            .offset = 0,
            .pixels_per_row = desc.extent.width,
            .rows_per_layer = desc.extent.height,
        };
        const destination = std.mem.zeroInit(c.SDL_GPUTextureRegion, .{
            .texture = handle.id,
            .w = desc.extent.width,
            .h = desc.extent.height,
            .d = desc.extent.depth,
        });

        c.SDL_UploadToGPUTexture(cmd.copy_pass, &source, &destination, true);

        cmd.endCopyPass();
    }
    return handle;
}

pub fn createTexture(self: *Renderer, desc: texture.Description) !texture.Handle {
    const texture_desc = c.SDL_GPUTextureCreateInfo{
        .type = c.SDL_GPU_TEXTURETYPE_2D,
        .format = desc.format.toSDLFormat(),
        .usage = desc.usage,
        .width = desc.extent.width,
        .height = desc.extent.height,
        .layer_count_or_depth = desc.extent.depth,
        .num_levels = 1,
        .sample_count = c.SDL_GPU_SAMPLECOUNT_1,
        .props = c.SDL_CreateProperties(),
    };

    if (desc.label) |label|
        _ = c.SDL_SetStringProperty(texture_desc.props, c.SDL_PROP_GPU_TEXTURE_CREATE_NAME_STRING, label.ptr);

    const texture_sdl = c.SDL_CreateGPUTexture(self.device, &texture_desc) orelse return SDL_ERROR.Fail;
    c.SDL_DestroyProperties(texture_desc.props);

    return texture.Handle{ .id = texture_sdl };
}

pub fn releaseTexture(self: *Renderer, handle: texture.Handle) void {
    _ = c.SDL_ReleaseGPUTexture(self.device, handle.id);
}

pub fn createSampler(self: *Renderer, desc: sampler.Description) !sampler.Handle {
    const sampler_create_info = c.SDL_GPUSamplerCreateInfo{
        .min_filter = desc.min_filter,
        .mag_filter = desc.mag_filter,
        .mipmap_mode = desc.mipmap_mode,
        .address_mode_u = desc.address_mode_u,
        .address_mode_v = desc.address_mode_v,
        .address_mode_w = desc.address_mode_w,
        .mip_lod_bias = desc.mip_lod_bias,
        .enable_anisotropy = desc.max_anisotropy != null,
        .max_anisotropy = if (desc.max_anisotropy) |max| max else 0.0,
        .enable_compare = desc.compare_op != null,
        .compare_op = if (desc.compare_op) |op| op else 0,
        .min_lod = desc.min_lod,
        .max_lod = desc.max_lod,
        .props = c.SDL_CreateProperties(),
    };

    if (desc.label) |label|
        _ = c.SDL_SetStringProperty(sampler_create_info.props, c.SDL_PROP_GPU_TEXTURE_CREATE_NAME_STRING, label.ptr);

    const sdl_sampler = c.SDL_CreateGPUSampler(self.device, &sampler_create_info) orelse return SDL_ERROR.Fail;
    c.SDL_DestroyProperties(sampler_create_info.props);

    return sampler.Handle{ .id = sdl_sampler };
}

pub fn releaseSampler(self: *Renderer, handle: sampler.Handle) void {
    _ = c.SDL_ReleaseGPUSampler(self.device, handle.id);
}

pub fn createBufferNamed(self: *Renderer, size: u32, usage_flags: u32, name: [:0]const u8) !*c.SDL_GPUBuffer {
    const buffer_desc = c.SDL_GPUBufferCreateInfo{
        .size = size,
        .usage = usage_flags,
        .props = c.SDL_CreateProperties(),
    };
    _ = c.SDL_SetStringProperty(buffer_desc.props, c.SDL_PROP_GPU_BUFFER_CREATE_NAME_STRING, name);
    const buf_vertex = c.SDL_CreateGPUBuffer(self.device, &buffer_desc) orelse return SDL_ERROR.Fail;
    c.SDL_DestroyProperties(buffer_desc.props);
    return buf_vertex;
}

pub fn releaseBuffer(self: *Renderer, buffer: *c.SDL_GPUBuffer) void {
    _ = c.SDL_ReleaseGPUBuffer(self.device, buffer);
}

pub fn createTransferBufferNamed(self: *Renderer, size: u32, usage_flags: u32, name: [:0]const u8) !*c.SDL_GPUTransferBuffer {
    const transfer_buffer_desc = c.SDL_GPUTransferBufferCreateInfo{
        .size = size,
        .usage = usage_flags,
        .props = c.SDL_CreateProperties(),
    };
    _ = c.SDL_SetStringProperty(transfer_buffer_desc.props, c.SDL_PROP_GPU_TRANSFERBUFFER_CREATE_NAME_STRING, name);
    const buf_transfer = c.SDL_CreateGPUTransferBuffer(self.device, &transfer_buffer_desc) orelse return SDL_ERROR.Fail;
    c.SDL_DestroyProperties(transfer_buffer_desc.props);
    return buf_transfer;
}

pub fn releaseTransferBuffer(self: *Renderer, buffer: *c.SDL_GPUTransferBuffer) void {
    _ = c.SDL_ReleaseGPUTransferBuffer(self.device, buffer);
}

pub fn copyToTransferBuffer(self: *Renderer, buffer: *c.SDL_GPUTransferBuffer, data: []const u8) void {
    const map = c.SDL_MapGPUTransferBuffer(self.device, buffer, true);
    _ = c.SDL_memcpy(map, data.ptr, data.len);
    c.SDL_UnmapGPUTransferBuffer(self.device, buffer);
}

pub fn acquireCommandBuffer(self: *Renderer) ?CommandBuffer {
    const cmd = c.SDL_AcquireGPUCommandBuffer(self.device) orelse return null;
    return .{ .handle = cmd };
}

const ShaderInfo = struct {
    num_inputs: usize,
    num_outputs: usize,
    num_uniform_buffers: usize,
    num_samplers: usize,
};

pub fn analyzeSpirv(code: []const u32) ShaderInfo {
    var context: spirv.spvc_context = undefined;
    if (spirv.spvc_context_create(&context) != 0) @panic("Fail");
    defer spirv.spvc_context_destroy(context);

    var parsed: spirv.spvc_parsed_ir = undefined;
    if (spirv.spvc_context_parse_spirv(context, code.ptr, code.len, &parsed) != 0) @panic("Fail");

    var compiler: spirv.spvc_compiler = undefined;
    if (spirv.spvc_context_create_compiler(context, spirv.SPVC_BACKEND_GLSL, parsed, spirv.SPVC_CAPTURE_MODE_TAKE_OWNERSHIP, &compiler) != 0) @panic("Fail");

    var resources: spirv.spvc_resources = undefined;
    if (spirv.spvc_compiler_create_shader_resources(compiler, &resources) != 0) @panic("Fail");

    var resource_list: [*c]const spirv.spvc_reflected_resource = undefined;
    var resource_list_size: usize = 0;

    var shader_info = std.mem.zeroInit(ShaderInfo, .{});

    // Input
    if (spirv.spvc_resources_get_resource_list_for_type(resources, spirv.SPVC_RESOURCE_TYPE_STAGE_INPUT, &resource_list, &resource_list_size) != 0) @panic("Fail");
    shader_info.num_inputs = resource_list_size;

    // Output
    if (spirv.spvc_resources_get_resource_list_for_type(resources, spirv.SPVC_RESOURCE_TYPE_STAGE_OUTPUT, &resource_list, &resource_list_size) != 0) @panic("Fail");
    shader_info.num_outputs = resource_list_size;

    // uniform
    if (spirv.spvc_resources_get_resource_list_for_type(resources, spirv.SPVC_RESOURCE_TYPE_UNIFORM_BUFFER, &resource_list, &resource_list_size) != 0) @panic("Fail");
    shader_info.num_uniform_buffers = resource_list_size;

    // num_samplers
    if (spirv.spvc_resources_get_resource_list_for_type(resources, spirv.SPVC_RESOURCE_TYPE_SAMPLED_IMAGE, &resource_list, &resource_list_size) != 0) @panic("Fail");
    shader_info.num_samplers = resource_list_size;
    return shader_info;
}

pub fn loadGlslShader(device: *c.SDL_GPUDevice, code: [*:0]const u8, name: [:0]const u8, stage: c_uint) !?*c.SDL_GPUShader {
    _ = spirv.glslang_initialize_process();
    defer spirv.glslang_finalize_process();

    const glslang_stage: c_uint = switch (stage) {
        c.SDL_GPU_SHADERSTAGE_VERTEX => spirv.GLSLANG_STAGE_VERTEX,
        c.SDL_GPU_SHADERSTAGE_FRAGMENT => spirv.GLSLANG_STAGE_FRAGMENT,
        else => return error.Fail,
    };

    const input = spirv.glslang_input_t{
        .language = spirv.GLSLANG_SOURCE_GLSL,
        .stage = glslang_stage,
        .client = spirv.GLSLANG_CLIENT_VULKAN,
        .client_version = spirv.GLSLANG_TARGET_VULKAN_1_4,
        .target_language = spirv.GLSLANG_TARGET_SPV,
        .target_language_version = spirv.GLSLANG_TARGET_SPV_1_0,
        .code = code,
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
        return null;
    }
    if (spirv.glslang_shader_parse(shader, &input) == 0) {
        std.log.warn("Parse failed", .{});
        std.log.warn("{s}", .{spirv.glslang_shader_get_info_log(shader)});
        std.log.warn("{s}", .{spirv.glslang_shader_get_info_debug_log(shader)});
        std.log.warn("{s}", .{spirv.glslang_shader_get_preprocessed_code(shader)});
        return null;
    }
    const program = spirv.glslang_program_create();
    spirv.glslang_program_add_shader(program, shader);

    if (spirv.glslang_program_link(program, spirv.GLSLANG_MSG_SPV_RULES_BIT | spirv.GLSLANG_MSG_VULKAN_RULES_BIT) == 0) {
        std.log.warn("Link failed", .{});
        return null;
    }
    spirv.glslang_program_SPIRV_generate(program, glslang_stage);
    const length = spirv.glslang_program_SPIRV_get_size(program);
    const res = std.heap.page_allocator.alloc(u32, length) catch @panic("OOM");
    defer std.heap.page_allocator.free(res);
    spirv.glslang_program_SPIRV_get(program, res.ptr);

    return loadSPIRVShader(device, res, name, stage);
}

pub fn loadSPIRVShader(device: *c.SDL_GPUDevice, _code: []const u32, name: [:0]const u8, stage: c_uint) !?*c.SDL_GPUShader {
    _ = name;
    const shader_info = analyzeSpirv(_code);
    const numBuffers: u32 = @intCast(shader_info.num_uniform_buffers);

    const code: []const u8 = @ptrCast(_code);
    const sci = std.mem.zeroInit(c.SDL_GPUShaderCreateInfo, .{
        .num_uniform_buffers = numBuffers,
        .num_samplers = @as(u32, @intCast(shader_info.num_samplers)),

        .format = c.SDL_GPU_SHADERFORMAT_SPIRV,
        .code = code.ptr,
        .code_size = code.len,
        .entrypoint = "main",

        .stage = stage,
    });
    return c.SDL_CreateGPUShader(device, &sci) orelse return SDL_ERROR.Fail;
}
