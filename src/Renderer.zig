const std = @import("std");
const Window = @import("Window.zig");
const CommandBuffer = @import("renderer/CommandBuffer.zig");
const SDL_ERROR = Window.SDL_ERROR;
const Image = @import("Image.zig");
pub const PixelFormat = @import("zigimg").PixelFormat;
const c = @import("solis").external.c;
const spirv = @import("solis").external.spirv;
pub const sampler = @import("renderer/sampler.zig");
pub const texture = @import("renderer/texture.zig");
pub const GraphicsPipeline = @import("renderer/GraphicsPipeline.zig");
pub const Shader = @import("renderer/Shader.zig");
pub const Buffer = @import("renderer/Buffer.zig");

const Renderer = @This();
window: *Window,
device: *c.SDL_GPUDevice,
sample_count: c.SDL_GPUSampleCount,

pub fn init(window: *Window) !Renderer {
    // GPU Device init
    const device = c.SDL_CreateGPUDevice(c.SDL_GPU_SHADERFORMAT_SPIRV, true, null) orelse return SDL_ERROR.Fail;
    if (!c.SDL_ClaimWindowForGPUDevice(device, window.handle)) return SDL_ERROR.Fail;

    const sample_count: c.SDL_GPUSampleCount = c.SDL_GPU_SAMPLECOUNT_1;

    return .{ .window = window, .device = device, .sample_count = sample_count };
}

pub fn deinit(self: *Renderer) void {
    c.SDL_DestroyGPUDevice(self.device);
}

pub fn createGraphicsPipeline(self: Renderer, desc: GraphicsPipeline.Description) !GraphicsPipeline {
    // Shaders, Can be destroyed after pipeline is created
    const v_shader = loadSPIRVShader(self.device, desc.vertex_shader) catch |e| return e;
    defer c.SDL_ReleaseGPUShader(self.device, v_shader);
    const f_shader = loadSPIRVShader(self.device, desc.fragment_shader) catch |e| return e;
    defer c.SDL_ReleaseGPUShader(self.device, f_shader);

    // Graphics Pipeline
    const color_target_desc = std.mem.zeroInit(c.SDL_GPUColorTargetDescription, .{ .format = c.SDL_GetGPUSwapchainTextureFormat(self.device, self.window.handle) });

    const vertex_buffer_desc = std.mem.zeroInit(c.SDL_GPUVertexBufferDescription, .{
        .slot = 0,
        .input_rate = c.SDL_GPU_VERTEXINPUTRATE_VERTEX,
        .instance_step_rate = 0,
        .pitch = @sizeOf(f32) * 15,
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
        std.mem.zeroInit(c.SDL_GPUVertexAttribute, .{
            .buffer_slot = 0,
            .format = c.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT4,
            .location = 4,
            .offset = @sizeOf(f32) * 11,
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

        .multisample_state = .{ .sample_count = self.sample_count },
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
            .front_face = c.SDL_GPU_FRONTFACE_CLOCKWISE,
        },
        .props = 0,
    });
    const pipeline = c.SDL_CreateGPUGraphicsPipeline(self.device, &pipelinedesc);
    if (pipeline == null) return SDL_ERROR.Fail;
    return GraphicsPipeline{ .handle = pipeline.?, .vertex_shader = desc.vertex_shader, .fragment_shader = desc.fragment_shader };
}

pub fn destroyGraphicsPipeline(self: Renderer, pipeline: GraphicsPipeline) void {
    c.SDL_ReleaseGPUGraphicsPipeline(self.device, pipeline.handle);
}

pub fn createTextureFromImage(self: *Renderer, image: Image) !texture.Handle {
    return self.createTextureWithData(.{
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

pub fn createBufferNamed(self: *Renderer, size: u32, usage_flags: u32, name: [:0]const u8) !Buffer {
    const buffer_desc = c.SDL_GPUBufferCreateInfo{
        .size = size,
        .usage = usage_flags,
        .props = c.SDL_CreateProperties(),
    };
    _ = c.SDL_SetStringProperty(buffer_desc.props, c.SDL_PROP_GPU_BUFFER_CREATE_NAME_STRING, name);
    const buf_vertex = c.SDL_CreateGPUBuffer(self.device, &buffer_desc) orelse return SDL_ERROR.Fail;
    c.SDL_DestroyProperties(buffer_desc.props);
    return .{.handle = buf_vertex, .size = size};
}

pub fn createBufferFromData(self: *Renderer, data: []const u8, usage_flags: u32, name: [:0]const u8) !Buffer {
    const buffer_size: u32 = @intCast(data.len);
    const buffer = try self.createBufferNamed(buffer_size, usage_flags, name);
    try self.uploadDataToBuffer(0, buffer, data);
    return buffer;
}

pub fn uploadDataToBuffer(self: *Renderer, dst_offset: u32, dst: Buffer, data: []const u8) !void {
    // TODO: Reuse TransferBuffers
    const buf_transfer = self.createTransferBufferNamed(dst.size, c.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD, "Transfer Buffer") catch |e| return e;
    defer self.releaseTransferBuffer(buf_transfer);

    self.copyToTransferBuffer(buf_transfer, data);

    var cmd = self.acquireCommandBuffer() orelse return SDL_ERROR.Fail;
    defer cmd.submit();

    cmd.beginCopyPass();
    cmd.uploadToBuffer(buf_transfer, dst_offset, @intCast(data.len), dst);
    cmd.endCopyPass();
}

pub fn releaseBuffer(self: *Renderer, buffer: Buffer) void {
    _ = c.SDL_ReleaseGPUBuffer(self.device, buffer.handle);
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

pub fn loadSPIRVShader(device: *c.SDL_GPUDevice, shader: Shader) !?*c.SDL_GPUShader {
    const num_uniform_buffers: u32 = @intCast(shader.uniform_buffers.items.len);
    const num_storage_buffers: u32 = @intCast(shader.storage_buffers.items.len);
    const num_storage_textures: u32 = @intCast(shader.storage_textures.items.len);
    const num_samplers: u32 = @intCast(shader.samplers.items.len);
    const stage: u32 = switch (shader.stage) {
        .Vertex => c.SDL_GPU_SHADERSTAGE_VERTEX,
        .Fragment => c.SDL_GPU_SHADERSTAGE_FRAGMENT,
    };

    const code: []const u8 = @ptrCast(shader.code.items);
    const sci = c.SDL_GPUShaderCreateInfo{
        .format = c.SDL_GPU_SHADERFORMAT_SPIRV,
        .code = code.ptr,
        .code_size = code.len,
        .entrypoint = "main",
        .stage = stage,

        .num_uniform_buffers = num_uniform_buffers,
        .num_storage_buffers = num_storage_buffers,
        .num_storage_textures = num_storage_textures,
        .num_samplers = num_samplers,
    };
    return c.SDL_CreateGPUShader(device, &sci) orelse return SDL_ERROR.Fail;
}
