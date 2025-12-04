const std = @import("std");
const solis = @import("solis");
const c = solis.external.c;

const Self = @This();

world: solis.world.World,

// TODO: dont handle windows here.
window_handle: u64,

pub fn init(allocator: std.mem.Allocator) !Self {
    errdefer c.SDL_Log("Error: %s", c.SDL_GetError());
    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) return error.SDL_Init;

    var res: Self = undefined;

    res.world = solis.world.World.init();

    _ = res.world.registerGlobal(std.mem.Allocator, std.heap.page_allocator).*;

    try solis.assets.Server.initModule(allocator, &res.world);
    var asset_server = res.world.getGlobalMut(solis.assets.Server) orelse @panic("Failed to get AssetServer");
    try asset_server.register_importer(solis.Image, solis.assets.ImageImporter);

    res.world.registerEvent(solis.system_event.SystemEvent);
    try solis.input.initModule(allocator, &res.world);

    // Video subsystem & windows
    try solis.Window.initModule(allocator, &res.world);
    res.world.register(solis.Camera);
    res.world.register(solis.PBRMaterial);
    res.world.register(solis.Transformation);
    res.world.register(solis.light.Light);

    try solis.render.initModule(allocator, &res.world);

    res.window_handle = res.world.newEntity("Main Window");
    const window = res.world.set(res.window_handle, solis.Window, try solis.Window.init());
    const renderer = res.world.registerGlobal(solis.render.Renderer, try solis.render.Renderer.init(&res.world, window));
    try solis.defaults.TextureDefaults.init(allocator, renderer);
    _ = res.world.set(res.window_handle, solis.render.TextureHandle, try renderer.createDepthTexture(window.size));

    return res;
}

pub fn deinit(self: *Self) void {
    const renderer = self.world.getGlobalMut(solis.render.Renderer).?;
    renderer.releaseTexture(self.world.getMut(self.window_handle, solis.render.TextureHandle).*);
    solis.defaults.TextureDefaults.deinit(renderer);
    self.world.deinit();
}
