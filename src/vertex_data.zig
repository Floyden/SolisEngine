const std = @import("std");

pub const ElementType = enum {
    float1,
    float2,
    float3,
    float4,

    pub fn size(self: ElementType) u32 {
        switch (self) {
            .float1 => return @sizeOf(f32),
            .float2 => return @sizeOf(f32) * 2,
            .float3 => return @sizeOf(f32) * 3,
            .float4 => return @sizeOf(f32) * 4,
        }
    }
};

pub const ElementUsage = enum {
    position,
    normal,
    color,
    tangent,
    texcoord,
};

pub const ElementDesc = struct {
    type: ElementType,
    usage: ElementUsage,
    offset: u32,
    index: u32,
};
