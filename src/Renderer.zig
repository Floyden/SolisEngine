const std = @import("std");
const Window = @import("Window.zig");
const CommandBuffer = @import("CommandBuffer.zig");
const SDL_ERROR = Window.SDL_ERROR;
pub const c = Window.c;

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
    const vertex_shader = __init_shader(device, true) catch return SDL_ERROR.Fail;
    const fragment_shader = __init_shader(device, false) catch return SDL_ERROR.Fail;
    defer c.SDL_ReleaseGPUShader(device, vertex_shader);
    defer c.SDL_ReleaseGPUShader(device, fragment_shader);

    const sample_count: c.SDL_GPUSampleCount = c.SDL_GPU_SAMPLECOUNT_1;

    // Graphics Pipeline
    const color_target_desc = std.mem.zeroInit(c.SDL_GPUColorTargetDescription, .{ .format = c.SDL_GetGPUSwapchainTextureFormat(device, window.handle) });

    const vertex_buffer_desc = std.mem.zeroInit(c.SDL_GPUVertexBufferDescription, .{
        .slot = 0,
        .input_rate = c.SDL_GPU_VERTEXINPUTRATE_VERTEX,
        .instance_step_rate = 0,
        .pitch = @sizeOf(c.VertexData),
    });
    const vertex_attributes: [2]c.SDL_GPUVertexAttribute = .{
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

        .vertex_shader = vertex_shader,
        .fragment_shader = fragment_shader,

        .vertex_input_state = .{
            .num_vertex_buffers = 1,
            .vertex_buffer_descriptions = &vertex_buffer_desc,
            .num_vertex_attributes = 2,
            .vertex_attributes = &vertex_attributes,
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
    _ = c.SDL_SetStringProperty(transfer_buffer_desc.props, c.SDL_PROP_GPU_BUFFER_CREATE_NAME_STRING, name);
    const buf_transfer = c.SDL_CreateGPUTransferBuffer(self.device, &transfer_buffer_desc) orelse return SDL_ERROR.Fail;
    c.SDL_DestroyProperties(transfer_buffer_desc.props);
    return buf_transfer;
}

pub fn releaseTransferBuffer(self: *Renderer, buffer: *c.SDL_GPUTransferBuffer) void {
    _ = c.SDL_ReleaseGPUTransferBuffer(self.device, buffer);
}

pub fn copyToTransferBuffer(self: *Renderer, buffer: *c.SDL_GPUTransferBuffer, data: []const u8) void {
    const map = c.SDL_MapGPUTransferBuffer(self.device, buffer, false);
    _ = c.SDL_memcpy(map, data.ptr, data.len);
    c.SDL_UnmapGPUTransferBuffer(self.device, buffer);
}

pub fn acquireCommandBuffer(self: *Renderer) ?CommandBuffer {
    const cmd = c.SDL_AcquireGPUCommandBuffer(self.device) orelse return null;
    return .{ .handle = cmd };
}

fn __init_shader(device: *c.SDL_GPUDevice, is_vertex: bool) !*c.SDL_GPUShader {
    const sci = std.mem.zeroInit(c.SDL_GPUShaderCreateInfo, .{
        .num_uniform_buffers = @intFromBool(is_vertex),

        .format = c.SDL_GPU_SHADERFORMAT_SPIRV,
        .code = @as([*c]const u8, if (is_vertex) &c.cube_vert_spv else &c.cube_frag_spv),
        .code_size = if (is_vertex) c.cube_vert_spv_len else c.cube_frag_spv_len,
        .entrypoint = "main",

        .stage = @as(c_uint, if (is_vertex) c.SDL_GPU_SHADERSTAGE_VERTEX else c.SDL_GPU_SHADERSTAGE_FRAGMENT),
    });
    return c.SDL_CreateGPUShader(device, &sci) orelse return SDL_ERROR.Fail;
}
