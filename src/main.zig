const std = @import("std");
const c = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_gpu.h");
    @cInclude("shader.h");
    @cInclude("signal.h");
});

pub const SDL_ERROR = error{Fail};

pub fn init_shader(device: *c.SDL_GPUDevice, is_vertex: bool) !*c.SDL_GPUShader {
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

fn createDepthTexture(device: *c.SDL_GPUDevice, drawable: [2]i32, sample_count: anytype) ?*c.SDL_GPUTexture {
    const createinfo = c.SDL_GPUTextureCreateInfo{
        .type = c.SDL_GPU_TEXTURETYPE_2D,
        .format = c.SDL_GPU_TEXTUREFORMAT_D16_UNORM,
        .width = @intCast(drawable[0]),
        .height = @intCast(drawable[1]),
        .layer_count_or_depth = 1,
        .num_levels = 1,
        .sample_count = sample_count,
        .usage = c.SDL_GPU_TEXTUREUSAGE_DEPTH_STENCIL_TARGET,
        .props = 0,
    };

    return c.SDL_CreateGPUTexture(device, &createinfo);
}

pub fn main() !void {
    errdefer c.SDL_Log("Error: %s", c.SDL_GetError());

    // Video subsystem & windows
    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) return SDL_ERROR.Fail;
    defer c.SDL_Quit();
    var window_size: @Vector(2, c_int) = .{ 800, 600 };
    const window = c.SDL_CreateWindow("Hey", window_size[0], window_size[1], c.SDL_WINDOW_VULKAN | c.SDL_WINDOW_RESIZABLE) orelse return SDL_ERROR.Fail;
    defer c.SDL_DestroyWindow(window);

    if (!c.SDL_ShowWindow(window)) return SDL_ERROR.Fail;

    // GPU Device init
    const device = c.SDL_CreateGPUDevice(c.SDL_GPU_SHADERFORMAT_SPIRV, true, null) orelse return SDL_ERROR.Fail;
    defer c.SDL_DestroyGPUDevice(device);
    if (!c.SDL_ClaimWindowForGPUDevice(device, window)) return SDL_ERROR.Fail;

    // Shaders
    const vertex_shader = init_shader(device, true) catch return SDL_ERROR.Fail;
    const fragment_shader = init_shader(device, false) catch return SDL_ERROR.Fail;
    defer c.SDL_ReleaseGPUShader(device, vertex_shader);
    defer c.SDL_ReleaseGPUShader(device, fragment_shader);

    // Buffers
    const buffer_desc = c.SDL_GPUBufferCreateInfo{
        .size = c.triangle_data_size,
        .usage = c.SDL_GPU_BUFFERUSAGE_VERTEX,
        .props = c.SDL_CreateProperties(),
    };
    _ = c.SDL_SetStringProperty(buffer_desc.props, c.SDL_PROP_GPU_BUFFER_CREATE_NAME_STRING, "VertexBuffer");
    const buf_vertex = c.SDL_CreateGPUBuffer(device, &buffer_desc) orelse return SDL_ERROR.Fail;
    defer c.SDL_ReleaseGPUBuffer(device, buf_vertex);
    c.SDL_DestroyProperties(buffer_desc.props);

    // Transfer data
    {
        const transfer_buffer_desc = c.SDL_GPUTransferBufferCreateInfo{
            .size = c.triangle_data_size,
            .usage = c.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
            .props = c.SDL_CreateProperties(),
        };
        _ = c.SDL_SetStringProperty(transfer_buffer_desc.props, c.SDL_PROP_GPU_BUFFER_CREATE_NAME_STRING, "TransferBuffer");
        const buf_transfer = c.SDL_CreateGPUTransferBuffer(device, &transfer_buffer_desc) orelse return SDL_ERROR.Fail;
        defer c.SDL_ReleaseGPUTransferBuffer(device, buf_transfer);
        c.SDL_DestroyProperties(transfer_buffer_desc.props);

        const map = c.SDL_MapGPUTransferBuffer(device, buf_transfer, false);
        _ = c.SDL_memcpy(map, &c.triangle_data, c.triangle_data_size);
        c.SDL_UnmapGPUTransferBuffer(device, buf_transfer);

        const cmd = c.SDL_AcquireGPUCommandBuffer(device);
        const copy_pass = c.SDL_BeginGPUCopyPass(cmd);

        const buf_location = std.mem.zeroInit(c.SDL_GPUTransferBufferLocation, .{ .transfer_buffer = buf_transfer });
        const dst_region = std.mem.zeroInit(c.SDL_GPUBufferRegion, .{
            .buffer = buf_vertex,
            .size = c.triangle_data_size,
        });
        c.SDL_UploadToGPUBuffer(copy_pass, &buf_location, &dst_region, false);
        c.SDL_EndGPUCopyPass(copy_pass);
        _ = c.SDL_SubmitGPUCommandBuffer(cmd);
    }

    const sample_count: c.SDL_GPUSampleCount = c.SDL_GPU_SAMPLECOUNT_1;

    // Graphics Pipeline
    const color_target_desc = std.mem.zeroInit(c.SDL_GPUColorTargetDescription, .{ .format = c.SDL_GetGPUSwapchainTextureFormat(device, window) });

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
    defer c.SDL_ReleaseGPUGraphicsPipeline(device, pipeline);
    if (pipeline == null) return SDL_ERROR.Fail;

    // window textures

    var tex_depth = createDepthTexture(device, window_size, sample_count);
    if (tex_depth == null) return SDL_ERROR.Fail;
    defer c.SDL_ReleaseGPUTexture(device, tex_depth);

    // Main loop
    const matrix = [16]f32{
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0,
    };

    var done = false;
    var event: c.SDL_Event = undefined;
    while (!done) {
        while (c.SDL_PollEvent(&event) and !done) {
            switch (event.type) {
                c.SDL_EVENT_QUIT, c.SDL_EVENT_WINDOW_CLOSE_REQUESTED => done = true,
                else => {},
            }
        }
        c.SDL_Delay(16);
        const cmd = c.SDL_AcquireGPUCommandBuffer(device) orelse return SDL_ERROR.Fail;
        defer _ = c.SDL_SubmitGPUCommandBuffer(cmd);

        var swapchainTexture: ?*c.SDL_GPUTexture = null;
        if (!c.SDL_AcquireGPUSwapchainTexture(cmd, window, &swapchainTexture, null, null)) return SDL_ERROR.Fail;
        if (swapchainTexture == null) {
            _ = c.SDL_CancelGPUCommandBuffer(cmd);
            continue;
        }

        // TODO: Resize
        var current_window_size: @Vector(2, c_int) = .{ 0, 0 };
        _ = c.SDL_GetWindowSizeInPixels(window, &current_window_size[0], &current_window_size[1]);
        if (@reduce(.Or, window_size != current_window_size)) {
            window_size = current_window_size;
            c.SDL_ReleaseGPUTexture(device, tex_depth);
            tex_depth = createDepthTexture(device, window_size, sample_count);
            if (tex_depth == null) return SDL_ERROR.Fail;
        }

        var color_target = std.mem.zeroInit(c.SDL_GPUColorTargetInfo, .{
            .texture = swapchainTexture,
            .clear_color = .{ .r = 0.1, .g = 0.1, .b = 0.1, .a = 1.0 },
            .load_op = c.SDL_GPU_LOADOP_CLEAR,
            .store_op = c.SDL_GPU_STOREOP_STORE,
        });
        var depth_target = std.mem.zeroInit(c.SDL_GPUDepthStencilTargetInfo, .{
            .clear_depth = 1.0,
            .load_op = c.SDL_GPU_LOADOP_CLEAR,
            .store_op = c.SDL_GPU_STOREOP_DONT_CARE,
            .stencil_load_op = c.SDL_GPU_LOADOP_DONT_CARE,
            .stencil_store_op = c.SDL_GPU_STOREOP_DONT_CARE,
            .texture = tex_depth,
            .cycle = true,
        });

        const vertex_binding = c.SDL_GPUBufferBinding{ .buffer = buf_vertex, .offset = 0 };
        c.SDL_PushGPUVertexUniformData(cmd, 0, &matrix, @sizeOf(f32) * matrix.len);
        const pass = c.SDL_BeginGPURenderPass(cmd, &color_target, 1, &depth_target);
        c.SDL_BindGPUGraphicsPipeline(pass, pipeline);
        c.SDL_BindGPUVertexBuffers(pass, 0, &vertex_binding, 1);
        c.SDL_DrawGPUPrimitives(pass, 3, 1, 0, 0);
        c.SDL_EndGPURenderPass(pass);
    }
}
