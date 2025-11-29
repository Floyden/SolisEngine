const std = @import("std");

const solis = @import("solis");
const c = solis.external.c;
const Image = solis.Image;
const Window = solis.Window;
const SDL_ERROR = Window.SDL_ERROR;
const World = solis.world.World;

const Buffer = @import("Buffer.zig");
const CommandBuffer = @import("CommandBuffer.zig");
const GraphicsPipeline = @import("GraphicsPipeline.zig");
const sampler = @import("sampler.zig");
const Shader = @import("Shader.zig");
const texture = @import("texture.zig");
const assets = solis.assets;

const Renderer = @This();
window: *Window,
world: *World,
device: *c.SDL_GPUDevice,
sample_count: c.SDL_GPUSampleCount,

/// Initializes the Renderer with a given window. Returns an error if it is unable to create a GPU device or claim the window.
// TODO: do not make the init depend on window
pub fn init(world: *World, window: *Window) !Renderer {
    const device = c.SDL_CreateGPUDevice(c.SDL_GPU_SHADERFORMAT_SPIRV, true, null) orelse return error.UnableToCreateGPUDevice;
    if (!c.SDL_ClaimWindowForGPUDevice(device, window.handle)) return error.UnableToClaimWindowForGPU;

    const sample_count: c.SDL_GPUSampleCount = c.SDL_GPU_SAMPLECOUNT_1;

    return .{ .world = world, .window = window, .device = device, .sample_count = sample_count };
}

/// Deinitializes the Renderer and releases associated resources
pub fn deinit(self: *Renderer) void {
    c.SDL_DestroyGPUDevice(self.device);
}

/// Creates a graphics pipeline with the specified description. Returns an error if the shader or pipeline creation fails.
pub fn createGraphicsPipeline(self: Renderer, asset_server: *assets.Server, desc: GraphicsPipeline.Description) !GraphicsPipeline {
    const vertex_shader = switch (desc.vertex_shader) {
        .handle => |shader| shader,
        .path => |path| asset_server.fetch(Shader, path).?.*,
    };

    const fragment_shader = switch (desc.fragment_shader) {
        .handle => |shader| shader,
        .path => |path| asset_server.fetch(Shader, path).?.*,
    };

    // Shaders, Can be destroyed after pipeline is created
    const v_shader = try loadSPIRVShader(self.device, vertex_shader);
    defer c.SDL_ReleaseGPUShader(self.device, v_shader);
    const f_shader = try loadSPIRVShader(self.device, fragment_shader);
    defer c.SDL_ReleaseGPUShader(self.device, f_shader);

    // Graphics Pipeline
    const color_target_desc = std.mem.zeroInit(c.SDL_GPUColorTargetDescription, .{ .format = c.SDL_GetGPUSwapchainTextureFormat(self.device, self.window.handle) });

    var vertex_offset: u32 = 0;
    var vertex_attributes: [16]c.SDL_GPUVertexAttribute = undefined;
    for (vertex_shader.inputs.items, 0..) |input, i| {
        vertex_attributes[i] = .{
            .location = @intCast(i),
            .buffer_slot = 0,
            .format = input.getElementFormat(),
            .offset = vertex_offset,
        };
        vertex_offset += input.getSize();
    }

    const vertex_buffer_desc = std.mem.zeroInit(c.SDL_GPUVertexBufferDescription, .{
        .slot = 0,
        .input_rate = c.SDL_GPU_VERTEXINPUTRATE_VERTEX,
        .instance_step_rate = 0,
        .pitch = vertex_offset,
    });

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
            .num_vertex_attributes = @as(u32, @intCast(vertex_shader.inputs.items.len)),
            .vertex_attributes = &vertex_attributes,
        },
        .rasterizer_state = .{
            .cull_mode = c.SDL_GPU_CULLMODE_FRONT,
            .front_face = c.SDL_GPU_FRONTFACE_CLOCKWISE,
        },
        .props = 0,
    });
    const pipeline = c.SDL_CreateGPUGraphicsPipeline(self.device, &pipelinedesc) orelse return error.GraphicsPipelineCreationFailed;
    return GraphicsPipeline{ .handle = pipeline, .vertex_shader = vertex_shader, .fragment_shader = fragment_shader };
}

/// Releases the provided GraphicsPipeline
pub fn destroyGraphicsPipeline(self: Renderer, pipeline: GraphicsPipeline) void {
    c.SDL_ReleaseGPUGraphicsPipeline(self.device, pipeline.handle);
}

pub fn createDefaultGraphicsPipeline(self: Renderer, asset_server: *assets.Server) !GraphicsPipeline {
    return try self.createGraphicsPipeline(
        asset_server,
        .{
            .vertex_shader = .{ .path = "./assets/shaders/default.vert" },
            .fragment_shader = .{ .path = "./assets/shaders/default.frag" },
        },
    );
}

/// Creates a 2D texture from an image.
/// Returns a texture handle or an error if creation fails.
pub fn createTextureFromImage(self: *Renderer, image: Image) !texture.Handle {
    return self.createTextureWithData(.{
        .extent = image.extent,
        .format = image.format,
        .usage = .sampler,
        .type = .image2d,
    }, image.rawBytes());
}

/// Creates a texture with the given description and data.
/// Returns a texture handle or an error if creation fails.
pub fn createTextureWithData(self: *Renderer, desc: texture.Description, data: []const u8) !texture.Handle {
    const handle = try self.createTexture(desc);

    // Transfer image data
    const transfer_buffer = try self.createTransferBufferNamed(@intCast(data.len), c.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD, "TexTransferBuffer");
    defer self.releaseTransferBuffer(transfer_buffer);

    self.copyToTransferBuffer(transfer_buffer, data, 0);

    var command_buffer = try self.acquireCommandBuffer();
    defer command_buffer.submit();

    command_buffer.beginCopyPass();
    // TODO: Export this part to the cmdbuffer
    const source = c.SDL_GPUTextureTransferInfo{
        .transfer_buffer = transfer_buffer,
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

    c.SDL_UploadToGPUTexture(command_buffer.copy_pass, &source, &destination, true);

    command_buffer.endCopyPass();
    return handle;
}

/// Creates a texture with the given description.
/// Returns a texture handle or an error if creation fails.
pub fn createTexture(self: *Renderer, desc: texture.Description) !texture.Handle {
    const texture_desc = c.SDL_GPUTextureCreateInfo{
        .type = desc.type.toSDLFormat(),
        .format = desc.format.toSDLFormat(),
        .usage = desc.usage.toSDLFormat(),
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

/// Releases the specified texture handle.
pub fn releaseTexture(self: *Renderer, handle: texture.Handle) void {
    _ = c.SDL_ReleaseGPUTexture(self.device, handle.id);
}

/// Creates a sampler with the given description.
/// Returns a sampler handle or an error if creation fails.
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

/// Releases the specified sampler handle.
pub fn releaseSampler(self: *Renderer, handle: sampler.Handle) void {
    _ = c.SDL_ReleaseGPUSampler(self.device, handle.id);
}

/// Creates a buffer with the specified size, usage flags, and name.
/// Returns a buffer or an error if creation fails.
pub fn createBufferNamed(self: *Renderer, size: u32, usage_flags: u32, name: [:0]const u8) !Buffer {
    const buffer_desc = c.SDL_GPUBufferCreateInfo{
        .size = size,
        .usage = usage_flags,
        .props = c.SDL_CreateProperties(),
    };
    _ = c.SDL_SetStringProperty(buffer_desc.props, c.SDL_PROP_GPU_BUFFER_CREATE_NAME_STRING, name);
    const buf_vertex = c.SDL_CreateGPUBuffer(self.device, &buffer_desc) orelse return SDL_ERROR.Fail;
    c.SDL_DestroyProperties(buffer_desc.props);
    return .{ .handle = buf_vertex, .size = size };
}

/// Creates a buffer from the provided data, usage flags, and name.
/// Returns a buffer or an error if creation fails.
pub fn createBufferFromData(self: *Renderer, data: []const u8, usage_flags: u32, name: [:0]const u8) !Buffer {
    const buffer_size: u32 = @intCast(data.len);
    const buffer = try self.createBufferNamed(buffer_size, usage_flags, name);
    try self.uploadDataToBuffer(0, buffer, data);
    return buffer;
}

/// Uploads data to a specified buffer at a given offset.
/// Returns an error if the upload fails.
pub fn uploadDataToBuffer(self: *Renderer, dst_offset: u32, dst: Buffer, data: []const u8) !void {
    // TODO: Reuse TransferBuffers
    const transfer_buffer = try self.createTransferBufferNamed(dst.size, c.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD, "Transfer Buffer");
    defer self.releaseTransferBuffer(transfer_buffer);

    self.copyToTransferBuffer(transfer_buffer, data, 0);

    var command_buffer = try self.acquireCommandBuffer();
    defer command_buffer.submit();

    command_buffer.beginCopyPass();
    command_buffer.uploadToBuffer(transfer_buffer, dst_offset, @intCast(data.len), dst);
    command_buffer.endCopyPass();
}

/// Releases the specified buffer.
pub fn releaseBuffer(self: *Renderer, buffer: Buffer) void {
    _ = c.SDL_ReleaseGPUBuffer(self.device, buffer.handle);
}

/// Creates a transfer buffer with the specified size, usage flags, and name.
/// Returns a transfer buffer or an error if creation fails.
pub fn createTransferBufferNamed(self: *Renderer, size: u32, usage_flags: u32, name: [:0]const u8) !*c.SDL_GPUTransferBuffer {
    const transfer_buffer_desc = c.SDL_GPUTransferBufferCreateInfo{
        .size = size,
        .usage = usage_flags,
        .props = c.SDL_CreateProperties(),
    };
    _ = c.SDL_SetStringProperty(transfer_buffer_desc.props, c.SDL_PROP_GPU_TRANSFERBUFFER_CREATE_NAME_STRING, name);
    const transfer_buffer = c.SDL_CreateGPUTransferBuffer(self.device, &transfer_buffer_desc) orelse return error.TransferBufferCreationFailed;
    c.SDL_DestroyProperties(transfer_buffer_desc.props);
    return transfer_buffer;
}

/// Releases the specified transfer buffer.
pub fn releaseTransferBuffer(self: *Renderer, buffer: *c.SDL_GPUTransferBuffer) void {
    _ = c.SDL_ReleaseGPUTransferBuffer(self.device, buffer);
}

/// Copies data to a transfer buffer at a specified offset.
pub fn copyToTransferBuffer(self: *Renderer, buffer: *c.SDL_GPUTransferBuffer, data: []const u8, dst_offset: u32) void {
    const mapped: [*]u8 = @ptrCast(c.SDL_MapGPUTransferBuffer(self.device, buffer, true));
    _ = c.SDL_memcpy(mapped + dst_offset, data.ptr, data.len);
    c.SDL_UnmapGPUTransferBuffer(self.device, buffer);
}

/// Acquires a command buffer for submitting GPU commands.
/// Returns a command buffer or an error if acquisition fails.
pub fn acquireCommandBuffer(self: *Renderer) !CommandBuffer {
    const command_buffer = c.SDL_AcquireGPUCommandBuffer(self.device) orelse return error.CommandBufferAcquisitionFailed;
    return .{ .handle = command_buffer };
}

fn loadSPIRVShader(device: *c.SDL_GPUDevice, shader: Shader) !*c.SDL_GPUShader {
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
    return c.SDL_CreateGPUShader(device, &sci) orelse return error.ShaderCreationFailed;
}
