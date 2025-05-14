const c = @import("solis").external.c;
pub const SDL_ERROR = error{Fail};
const Window = @This();

handle: ?*c.SDL_Window,
size: [2]u32,
has_resized: bool,

pub fn init() !Window {
    const window_size = [2]u32{ 1600, 900 };
    const window = c.SDL_CreateWindow("Hey", window_size[0], window_size[1], c.SDL_WINDOW_VULKAN | c.SDL_WINDOW_RESIZABLE) orelse return SDL_ERROR.Fail;
    if (!c.SDL_ShowWindow(window)) return SDL_ERROR.Fail;
    return .{ .handle = window, .size = window_size, .has_resized = true };
}

pub fn deinit(self: *Window) void {
    c.SDL_DestroyWindow(self.handle);
    self.handle = null;
}

pub fn update(self: *Window) void {
    var current_window_size = [2]u32{ 0, 0 };
    _ = c.SDL_GetWindowSizeInPixels(self.handle, @ptrCast(&current_window_size[0]), @ptrCast(&current_window_size[1]));
    if (self.size[0] != current_window_size[0] or self.size[1] != current_window_size[1]) {
        self.size = current_window_size;
        self.has_resized = true;
    } else {
        self.has_resized = false;
    }
}

pub fn getAspect(self: Window) f32 {
    const width: f32 = @floatFromInt(self.size[0]);
    const height: f32 = @floatFromInt(self.size[1]);
    return width / height;
}

// Window Events
pub const Resized = struct {
    window: c.SDL_WindowID, // TODO: Abstract this away
    width: i32,
    height: i32,
};

pub const Event = union {
    resized: Resized
};
