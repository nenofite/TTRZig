const std = @import("std");
const builtin = @import("builtin");
const pdapi = @import("playdate_api_definitions.zig");
pub usingnamespace pdapi;

pub var playdate: *pdapi.PlaydateAPI = undefined;
var randomStorage: std.Random.Pcg = undefined;
pub var random: std.Random = undefined;

pub var locoMotion: *pdapi.LCDFont = undefined;
pub var mans: *pdapi.LCDFont = undefined;

pub fn init_playdate(pd: *pdapi.PlaydateAPI) void {
    playdate = pd;

    var msec: u32 = 0;
    const sec: u32 = playdate.system.getSecondsSinceEpoch(&msec);
    const seed: u64 = @as(u64, @intCast(sec)) << 32 | @as(u32, @intCast(msec));
    randomStorage = std.Random.Pcg.init(seed);
    random = randomStorage.random();
    locoMotion = loadFont("fonts/locomotion");
    playdate.graphics.setFont(locoMotion);
    mans = loadFont("fonts/mans");
}

pub const WIDTH = 400;
pub const HEIGHT = 240;

pub fn softFail() void {
    if (builtin.mode == .Debug) {
        @panic("soft failure");
    }
}

pub fn loadFont(path: [:0]const u8) *pdapi.LCDFont {
    const result = playdate.graphics.loadFont(@ptrCast(path), null);
    if (result == null) {
        playdate.system.@"error"("Could not load font");
    }
    return result.?;
}

pub const Dpad = enum {
    none,
    up,
    right,
    down,
    left,
};

pub const ButtonState = struct {
    current: pdapi.PDButtons = 0,
    pushed: pdapi.PDButtons = 0,
    released: pdapi.PDButtons = 0,
};

pub fn getButtonState() ButtonState {
    var result = ButtonState{};
    playdate.system.getButtonState(&result.current, &result.pushed, &result.released);
    return result;
}

pub fn isButtonJustPressed(btn: pdapi.PDButtons) bool {
    var pushed: pdapi.PDButtons = 0;
    playdate.system.getButtonState(null, &pushed, null);
    return pushed & btn != 0;
}

pub fn dpad() Dpad {
    var pushed: pdapi.PDButtons = 0;
    playdate.system.getButtonState(&pushed, null, null);
    if (pushed & pdapi.BUTTON_UP != 0) {
        return .up;
    } else if (pushed & pdapi.BUTTON_RIGHT != 0) {
        return .right;
    } else if (pushed & pdapi.BUTTON_DOWN != 0) {
        return .down;
    } else if (pushed & pdapi.BUTTON_LEFT != 0) {
        return .left;
    } else {
        return .none;
    }
}

pub const ButtonTracker = struct {
    button: pdapi.PDButtons,
    state: enum {
        init,
        pressed,
        released,
    } = .init,
    invert: bool = false,

    pub fn check(self: *ButtonTracker) bool {
        switch (self.state) {
            .init => {
                const pushed = getButtonState().current & self.button != 0;
                if (pushed != self.invert) {
                    self.state = .pressed;
                }
                return false;
            },
            .pressed => {
                const pushed = getButtonState().current & self.button != 0;
                if (pushed == self.invert) {
                    self.state = .released;
                }
                return false;
            },
            .released => {
                return true;
            },
        }
    }

    pub fn reset(self: *ButtonTracker) void {
        self.state = .init;
    }
};
