pub const MouseMotion = struct {
    abs: [2]f32,
    rel: [2]f32,
};

pub const MouseButton = struct {
    button: u8,
    down: bool,
    clicks: u8,

    pos: [2]f32,
};
