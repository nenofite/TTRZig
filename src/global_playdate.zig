const std = @import("std");
const builtin = @import("builtin");
const pdapi = @import("playdate_api_definitions.zig");
pub usingnamespace pdapi;

pub var playdate: *pdapi.PlaydateAPI = undefined;
var randomStorage: std.Random.Pcg = undefined;
pub var random: std.Random = undefined;

pub var geo: *pdapi.LCDFont = undefined;
pub var mans: *pdapi.LCDFont = undefined;

var prevLogTime: ?u32 = null;

pub fn init_playdate(pd: *pdapi.PlaydateAPI) void {
    playdate = pd;

    var msec: u32 = 0;
    const sec: u32 = playdate.system.getSecondsSinceEpoch(&msec);
    const seed: u64 = @as(u64, @intCast(sec)) << 32 | @as(u32, @intCast(msec));
    randomStorage = std.Random.Pcg.init(seed);
    random = randomStorage.random();
    geo = loadFont("fonts/geo");
    playdate.graphics.setFont(geo);
    mans = loadFont("fonts/mans");
}

pub const WIDTH = 400;
pub const HEIGHT = 240;

pub fn softFail(msg: [:0]const u8) void {
    playdate.system.@"error"(msg);
    // if (builtin.mode == .Debug) {
    //     @panic(msg);
    // }
}

pub fn fmtPanic(comptime fmt: []const u8, args: anytype) noreturn {
    var buf = [1]u8{0} ** 1024;
    const msg = std.fmt.bufPrintZ(&buf, fmt, args) catch "(Format failure)";
    playdate.system.@"error"(msg);
    @panic(msg);
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

pub const Buttons = packed struct(c_int) {
    left: bool = false,
    right: bool = false,
    up: bool = false,
    down: bool = false,
    b: bool = false,
    a: bool = false,
    _extra: u26 = undefined,
};
// pub const BUTTON_LEFT = (1 << 0);
// pub const BUTTON_RIGHT = (1 << 1);
// pub const BUTTON_UP = (1 << 2);
// pub const BUTTON_DOWN = (1 << 3);
// pub const BUTTON_B = (1 << 4);
// pub const BUTTON_A = (1 << 5);

pub const ButtonState = struct {
    current: Buttons = .{},
    pushed: Buttons = .{},
    released: Buttons = .{},
};

pub fn getButtonState() ButtonState {
    var result = ButtonState{};
    playdate.system.getButtonState(
        @ptrCast(&result.current),
        @ptrCast(&result.pushed),
        @ptrCast(&result.released),
    );
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

pub fn moveWithCollisions(sprite: *pdapi.LCDSprite, x: *f32, y: *f32) ?[]pdapi.SpriteCollisionInfo {
    var len: c_int = 0;
    const arrayOpt = playdate.sprite.moveWithCollisions(sprite, x.*, y.*, x, y, &len);
    if (arrayOpt) |array| {
        const lenSz: usize = @intCast(len);
        return array[0..lenSz];
    } else {
        return null;
    }
}

fn markTime() ?u32 {
    const now: u32 = playdate.system.getCurrentTimeMilliseconds();
    const prevOpt = prevLogTime;
    prevLogTime = now;
    if (prevOpt) |prev| {
        return now - prev;
    } else {
        return null;
    }
}

pub fn log(comptime fmt: []const u8, args: anytype) void {
    const elapsed = markTime() orelse 0;
    var buf = [1]u8{0} ** 1024;
    const fmtBuf = std.fmt.bufPrintZ(&buf, fmt, args) catch "(Format failed)";
    playdate.system.logToConsole("[+%ums] %s", elapsed, fmtBuf.ptr);
}

const alloc_impl = struct {
    fn alloc(ctx: *anyopaque, len: usize, ptr_align: u8, ret_addr: usize) ?[*]u8 {
        _ = ctx;
        _ = ptr_align;
        _ = ret_addr;
        const raw = playdate.system.realloc(null, len) orelse return null;
        const u8raw: [*]u8 = @ptrCast(@alignCast(raw));
        const buf = u8raw[0..len];
        @memset(buf, undefined);
        return u8raw;
    }

    fn resize(ctx: *anyopaque, buf: []u8, buf_align: u8, new_len: usize, ret_addr: usize) bool {
        _ = ctx;
        _ = buf_align;
        _ = ret_addr;

        _ = buf;
        _ = new_len;
        return false;
    }

    fn free(ctx: *anyopaque, buf: []u8, buf_align: u8, ret_addr: usize) void {
        _ = ctx;
        _ = buf_align;
        _ = ret_addr;
        @memset(buf, undefined);
        _ = playdate.system.realloc(buf.ptr, 0);
    }

    pub const allocator: std.mem.Allocator = .{
        .ptr = undefined,
        .vtable = &.{
            .alloc = alloc,
            .resize = resize,
            .free = free,
        },
    };
};

pub const allocator = alloc_impl.allocator;
