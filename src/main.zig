const std = @import("std");
const p = @import("global_playdate.zig");
const panic_handler = @import("panic_handler.zig");
const tween = @import("tween.zig");
const pat = @import("pattern.zig");
const icons = @import("icons.zig");
const sounds = @import("sounds.zig");
const images = @import("images.zig");

const StartScreen = @import("start_screen.zig").StartScreen;
const TutorialScreen = @import("tutorial_screen.zig").TutorialScreen;
const LoseScreen = @import("lose_screen.zig").LoseScreen;
const HealthBar = @import("health_bar.zig").HealthBar;
const StateEvent = @import("state_event.zig").StateEvent;
const CombatState = @import("combat_state.zig").CombatState;

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
    state.start();
}

const TopState = union(enum) {
    startScreen: StartScreen,
    tutorial: TutorialScreen,
    combat: CombatState,
    lose: LoseScreen,

    pub fn start(self: *TopState) void {
        // self.* = .{ .startScreen = .{} };
        // self.startScreen.start();
        self.* = .{ .tutorial = .{} };
        self.tutorial.start();
    }

    pub fn update(self: *TopState) void {
        const event: StateEvent = switch (self.*) {
            .startScreen => |*s| s.update(),
            .tutorial => |*t| t.update(),
            .combat => |*c| c.update(),
            .lose => |*l| l.update(),
        };
        switch (event) {
            .none => {},
            .tutorial => {
                self.* = .{ .tutorial = .{} };
                self.tutorial.start();
            },
            .combat => {
                self.* = .{ .combat = .{} };
                self.combat.start();
            },
            .lose => {
                self.* = .{ .lose = .{} };
                self.lose.start();
            },
        }
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
