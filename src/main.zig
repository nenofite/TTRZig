const std = @import("std");
const p = @import("global_playdate.zig");
const panic_handler = @import("panic_handler.zig");
const tween = @import("tween.zig");
const pat = @import("pattern.zig");
const icons = @import("icons.zig");
const sounds = @import("sounds.zig");
const images = @import("images.zig");

const SpriteArena = @import("sprite_arena.zig").SpriteArena;

pub const panic = panic_handler.panic;

pub export fn eventHandler(pd_: *p.PlaydateAPI, event: p.PDSystemEvent, arg: u32) callconv(.C) c_int {
    _ = arg;
    switch (event) {
        .EventInit => {
            //NOTE: Initalizing the panic handler should be the first thing that is done.
            //      If a panic happens before calling this, the simulator or hardware will
            //      just crash with no message.
            panic_handler.init(pd_);
            init(pd_);

            pd_.system.setUpdateCallback(update_and_render, null);
        },
        .EventTerminate => {
            deinit();
        },
        else => {},
    }
    return 0;
}

fn init(pd_: *p.PlaydateAPI) void {
    p.init_playdate(pd_);
    images.init();
    icons.init();
    sounds.init();
    p.playdate.display.setRefreshRate(tween.framerate);
    const allocd: ?*TopState = @ptrCast(@alignCast(p.playdate.system.realloc(null, @sizeOf(TopState))));
    state = allocd.?;
    state.* = TopState.init() catch @panic("Could not init TopState");
    p.playdate.system.logToConsole("Finished setup");
}

fn deinit() void {
    p.playdate.system.logToConsole("Tearing down");
    state.deinit();
}

const MainScreen = struct {
    arena: SpriteArena,

    pub fn init() !MainScreen {
        return .{
            .arena = try SpriteArena.init(p.allocator),
        };
    }

    pub fn deinit(self: *MainScreen) void {
        self.arena.deinit();
    }
};

const TopState = union(enum) {
    main: MainScreen,

    pub fn init() !TopState {
        return .{ .main = try MainScreen.init() };
    }

    pub fn deinit(self: *TopState) void {
        switch (self.*) {
            .main => |*main| main.deinit(),
        }
    }

    pub fn update(self: *TopState) void {
        _ = self;
    }
};

var state: *TopState = undefined;

fn update_and_render(userdata: ?*anyopaque) callconv(.C) c_int {
    _ = userdata;
    state.update();

    //returning 1 signals to the OS to draw the frame.
    //we always want this frame drawn
    return 1;
}
