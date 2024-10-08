const std = @import("std");
const p = @import("global_playdate.zig");
const panic_handler = @import("panic_handler.zig");
const tween = @import("tween.zig");
const pat = @import("pattern.zig");
const icons = @import("icons.zig");
const sounds = @import("sounds.zig");
const images = @import("images.zig");

const Arrow = @import("Arrow.zig");
const Haze = @import("Haze.zig");
const SpriteArena = @import("SpriteArena.zig");
const Camera = @import("Camera.zig");
const Gauge = @import("Gauge.zig");
const Coin = @import("Coin.zig");
const Score = @import("Score.zig");
const LevelParser = @import("LevelParser.zig");
const MainScreen = @import("MainScreen.zig");
const WinScreen = @import("WinScreen.zig");

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
    state = p.allocator.create(TopState) catch unreachable;
    state.* = TopState.init() catch unreachable; //@panic("Could not init TopState");
    p.log("Finished setup", .{});
}

fn deinit() void {
    p.log("Tearing down", .{});
    state.deinit();
}

const TopState = union(enum) {
    main: *MainScreen,
    win: *WinScreen,

    pub fn init() !TopState {
        const main = try MainScreen.init(0);
        errdefer main.deinit();

        return .{ .main = main };
        // return .{ .win = try WinScreen.init(main) };
    }

    pub fn deinit(self: *TopState) void {
        switch (self.*) {
            .main => |main| main.deinit(),
            .win => |win| win.deinit(),
        }
    }

    pub fn update(self: *TopState) !void {
        switch (self.*) {
            .main => |main| {
                const outcome = main.update();
                switch (outcome) {
                    .none => {},
                    .won => {
                        const win = try WinScreen.init(main);
                        self.* = .{ .win = win };
                    },
                }
            },
            .win => |win| {
                switch (win.update()) {
                    .none => {},
                    .start => |main| {
                        win.main = null;
                        win.deinit();
                        self.* = .{ .main = main };
                    },
                }
            },
        }
    }
};

var state: *TopState = undefined;

fn update_and_render(userdata: ?*anyopaque) callconv(.C) c_int {
    _ = userdata;
    state.update() catch |err| {
        var buf = [1]u8{0} ** 1024;
        const result = std.fmt.bufPrintZ(&buf, "Failed update: {any}", .{err}) catch "oop";
        p.softFail(result);
    };
    p.playdate.sprite.updateAndDrawSprites();

    // returning 1 signals to the OS to draw the frame.
    return 1;
}
