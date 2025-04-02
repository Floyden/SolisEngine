const c = @import("solis").external.c;
pub const SDL_ERROR = error{Fail};
const Window = @This();

handle: ?*c.SDL_Window,
size: @Vector(2, c_int),

pub fn init() !Window {
    const window_size: @Vector(2, c_int) = .{ 800, 600 };
    const window = c.SDL_CreateWindow("Hey", window_size[0], window_size[1], c.SDL_WINDOW_VULKAN | c.SDL_WINDOW_RESIZABLE) orelse return SDL_ERROR.Fail;
    if (!c.SDL_ShowWindow(window)) return SDL_ERROR.Fail;
    return .{ .handle = window, .size = window_size };
}

pub fn deinit(self: *Window) void {
    c.SDL_DestroyWindow(self.handle);
    self.handle = null;
}
