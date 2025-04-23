pub const c = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_gpu.h");
});

pub const spirv = @cImport({
    // @cInclude("shaderc/shaderc.h");
    @cInclude("glslang/Include/glslang_c_interface.h");
    @cInclude("glslang/Include/glslang_c_shader_types.h");
    @cInclude("glslang/Public/resource_limits_c.h");
    @cInclude("spirv_cross/spirv_cross_c.h");
});
