const std = @import("std");
const Extent3d = @import("solis").Extent3d;
const Image = @import("solis").Image;
const Renderer = @import("solis").Renderer;
const c = @import("solis").external.c;

const texture = @import("texture.zig");
const SamplerHandle = @import("sampler.zig").Handle;

const Self = @This();

specular_texture: texture.Handle, 
diffuse_texture: texture.Handle,

pub fn initFromImage(renderer: *Renderer, specular_image: Image, allocator: std.mem.Allocator) !Self {
    // TODO: MIPMAPS
    var diffuse_image = try generateDiffuse(specular_image, allocator);
    defer diffuse_image.deinit();

    return .{
        .specular_texture = try loadTexture(renderer, specular_image),
        .diffuse_texture = try loadTexture(renderer, diffuse_image),
    };
}

pub fn deinit(self: Self, renderer: *Renderer) void {
    renderer.releaseTexture(self.specular_texture);
    renderer.releaseTexture(self.diffuse_texture);
}

pub fn createSamplerBinding(self: Self, sampler: SamplerHandle) [2]c.SDL_GPUTextureSamplerBinding {
    // TODO: store sampler somewhere else
    return [_]c.SDL_GPUTextureSamplerBinding{
        .{ .sampler = sampler.id, .texture = self.specular_texture.id },
        .{ .sampler = sampler.id, .texture = self.diffuse_texture.id },
    };
}

fn generateDiffuse(specular_image: Image, allocator: std.mem.Allocator) !Image {
    // TODO: Implement different byte widths
    // TODO: This should probably be in Image.zig
    // TODO: This probably needs blurring too
    const extent = Extent3d{
        .width = specular_image.extent.width / 8,
        .height = specular_image.extent.height / 8,
    };

    std.debug.assert(specular_image.format == .rgba8unorm);

    var res = Image.init_empty(extent, specular_image.format, allocator);
    
    for(0..extent.height) |by| {
        for(0..extent.width) |bx| {
            var colors = [4]u32{0, 0, 0, 0};

            for(0..8) |y| {
                for(0..8) |x| {
                    const p_x = bx * 8 + x;
                    const p_y = by * 8 + y;
                    const idx = (p_y * specular_image.extent.width + p_x) * 4;
                    colors[0] += specular_image.data.items[idx + 0];
                    colors[1] += specular_image.data.items[idx + 1];
                    colors[2] += specular_image.data.items[idx + 2];
                    colors[3] += specular_image.data.items[idx + 3];
                }
            }

            for(colors) |val| res.data.appendAssumeCapacity(@intCast(val / 64));
        }
    }
    return res;
}


fn loadTexture(renderer: *Renderer, image: Image) !texture.Handle {
    const cube_extent = Extent3d{ .width = image.extent.width / 4, .height = image.extent.height / 3, .depth = 6};
    std.debug.assert(cube_extent.height == cube_extent.width);

    const offsets = [_]Extent3d{
        .{ .width = cube_extent.width * 2, .height = cube_extent.height * 1 }, // X-
        .{ .width = cube_extent.width * 0, .height = cube_extent.height * 1 }, // X+
        .{ .width = cube_extent.width * 1, .height = cube_extent.height * 0 }, // Y+
        .{ .width = cube_extent.width * 1, .height = cube_extent.height * 2 },
        .{ .width = cube_extent.width * 1, .height = cube_extent.height * 1 },
        .{ .width = cube_extent.width * 3, .height = cube_extent.height * 1 },
    };

    var images = [_]Image{
        image.extractRegion(cube_extent, offsets[0], image.allocator),
        image.extractRegion(cube_extent, offsets[1], image.allocator),
        image.extractRegion(cube_extent, offsets[2], image.allocator),
        image.extractRegion(cube_extent, offsets[3], image.allocator),
        image.extractRegion(cube_extent, offsets[4], image.allocator),
        image.extractRegion(cube_extent, offsets[5], image.allocator),
    };
    defer for (&images) |*img| img.deinit();

    const handle = try renderer.createTexture(.{
        .extent = cube_extent,
        .format = image.format,
        .usage = .sampler,
        .type = .cube,
        .label = "CubeMap",
    });

    const image_size: u32 = @intCast(images[0].rawBytes().len);
    const transfer_buffer = try renderer.createTransferBufferNamed(@intCast(image_size * images.len), c.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD, "CubeTextureTransferBuffer");
    defer renderer.releaseTransferBuffer(transfer_buffer);

    for (images, 0..) |img, i|
        renderer.copyToTransferBuffer(transfer_buffer, img.data.items, @intCast(image_size * i));

    var command_buffer = try renderer.acquireCommandBuffer();
    defer command_buffer.submit();

    command_buffer.beginCopyPass();
    // TODO: Export this part to the cmdbuffer
    for (0..6) |i| {
        const source = c.SDL_GPUTextureTransferInfo{
            .transfer_buffer = transfer_buffer,
            .offset = @intCast(image_size * i),
            .pixels_per_row = cube_extent.width,
            .rows_per_layer = cube_extent.height,
        };
        const destination = std.mem.zeroInit(c.SDL_GPUTextureRegion, .{
            .texture = handle.id,
            .w = cube_extent.width,
            .h = cube_extent.height,
            .d = 1,
            .layer = @as(u32, @intCast(i)),
        });

        c.SDL_UploadToGPUTexture(command_buffer.copy_pass, &source, &destination, false);
    }
    command_buffer.endCopyPass();
    return handle;
}


