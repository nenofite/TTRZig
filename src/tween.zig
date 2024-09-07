const std = @import("std");
const p = @import("global_playdate.zig");

const maxDiscreteSize = @sizeOf(*void);

pub const framerate = 50;
pub const framerateF: comptime_float = @floatFromInt(framerate);
const frameMsec = @divTrunc(1000, framerate);

pub const Target = union(enum) {
    none: void,
    f32: struct {
        target: *f32,
        from: ?f32,
        to: f32,
    },
    i32: struct {
        target: *i32,
        from: ?i32,
        to: i32,
    },
    discrete: struct {
        target: []u8,
        to: [maxDiscreteSize]u8,
    },
    slice: struct {
        target: []u8,
        to: []const u8,
    },
    spritePos: struct {
        target: *p.LCDSprite,
        from: ?[2]f32,
        to: [2]?f32,
    },
    callback: struct {
        ctx: *anyopaque,
        func: *const fn (*anyopaque) void,
    },

    fn apply(self: *Target, f: f32) void {
        switch (self.*) {
            .none => {},
            .f32 => |*t| {
                const from_ = t.from orelse b: {
                    const targV = t.target.*;
                    t.from = targV;
                    break :b targV;
                };
                const diff = t.to - from_;
                t.target.* = from_ + f * diff;
            },
            .i32 => |*t| {
                const from_ = t.from orelse b: {
                    const targV = t.target.*;
                    t.from = targV;
                    break :b targV;
                };
                const diff: f32 = @floatFromInt(t.to - from_);
                t.target.* = from_ + @as(i32, @intFromFloat(f * diff));
            },
            .discrete, .slice, .callback => {},
            .spritePos => |*t| {
                const from = t.from orelse calcFrom: {
                    var from_ = [2]f32{ 0, 0 };
                    p.playdate.sprite.getPosition(t.target, &from_[0], &from_[1]);
                    t.from = from_;
                    break :calcFrom from_;
                };
                const toX = t.to[0] orelse from[0];
                const toY = t.to[1] orelse from[1];
                const diffX = toX - from[0];
                const diffY = toY - from[1];
                p.playdate.sprite.moveTo(t.target, from[0] + f * diffX, from[1] + f * diffY);
            },
        }
    }

    fn fast_forward(self: *const Target) void {
        switch (self.*) {
            .none => {},
            .f32 => |t| {
                t.target.* = t.to;
            },
            .i32 => |t| {
                t.target.* = t.to;
            },
            .discrete => |*t| {
                std.debug.assert(t.target.len <= t.to.len);
                const toSlice = t.to[0..t.target.len];
                @memcpy(t.target, toSlice);
            },
            .slice => |*t| {
                std.debug.assert(t.target.len == t.to.len);
                @memcpy(t.target, t.to);
            },
            .spritePos => |t| {
                var curX: f32 = 0;
                var curY: f32 = 0;
                p.playdate.sprite.getPosition(t.target, &curX, &curY);
                p.playdate.sprite.moveTo(t.target, t.to[0] orelse curX, t.to[1] orelse curY);
            },
            .callback => |t| {
                t.func(t.ctx);
            },
        }
    }
};

pub const Ease = struct {
    curve: enum {
        linear,
        quad,
        cubic,
    },
    ends: enum {
        inout,
        in,
        out,
    },

    pub const linear = Ease{ .curve = .linear, .ends = .inout };

    fn apply(self: *const Ease, original: f32) f32 {
        const original_ = clamp01(original);

        // shortcut
        if (self.curve == .linear) return clamp01(original_);

        const input = switch (self.ends) {
            .in => original_,
            .out => 1 - original_,
            .inout => 1 - @abs(original_ * 2 - 1),
        };
        const curved = switch (self.curve) {
            .linear => input,
            .quad => input * input,
            .cubic => input * input * input,
        };
        const output = switch (self.ends) {
            .in => curved,
            .out => 1 - curved,
            .inout => if (original_ <= 0.5) curved * 0.5 else 1 - curved * 0.5,
        };
        return clamp01(output);
    }

    fn clamp01(v: f32) f32 {
        return std.math.clamp(v, 0.0, 1.0);
    }
};

pub const Tween = struct {
    target: Target,
    ease: Ease,
    delay: u32,
    dur: u32,
    elapsed: u32 = 0,

    pub fn update(self: *Tween) bool {
        self.elapsed += frameMsec;
        var elapsed = self.elapsed;
        if (elapsed < self.delay) return false;
        elapsed -|= self.delay;
        if (elapsed >= self.dur) {
            self.target.fast_forward();
            return true;
        } else {
            var f = @as(f32, @floatFromInt(elapsed)) / @as(f32, @floatFromInt(self.dur));
            f = std.math.clamp(f, 0, 1);
            f = self.ease.apply(f);
            self.target.apply(f);
            return false;
        }
    }

    pub fn fast_forward(self: *const Tween) void {
        self.target.fast_forward();
    }
};

pub const List = struct {
    storage: std.ArrayList(Tween),

    pub fn init(alloc: std.mem.Allocator) !List {
        return .{
            .storage = std.ArrayList(Tween).init(alloc),
        };
    }

    pub fn deinit(self: *List) void {
        self.storage.deinit();
    }

    pub fn isActive(self: *const List) bool {
        return self.storage.items.len > 0;
    }

    pub fn update(self: *List) bool {
        var i: usize = 0;
        while (i < self.storage.items.len) {
            if (self.storage.items[i].update()) {
                self.remove(i);
            } else {
                i += 1;
            }
        }
        return self.isActive();
    }

    fn remove(self: *List, i: usize) void {
        std.debug.assert(i < self.storage.items.len);
        _ = self.storage.swapRemove(i);
    }

    pub fn cancelClear(self: *List) void {
        self.storage.resize(0) catch unreachable;
    }

    pub fn finishClear(self: *List) void {
        for (self.storage.items) |*t| {
            t.fast_forward();
        }
        self.cancelClear();
    }

    pub fn add(self: *List, tween: Tween) !void {
        try self.storage.append(tween);
    }

    pub fn addIfRoom(self: *List, tween: Tween) void {
        self.storage.append(tween) catch {};
    }

    pub fn addOrFF(self: *List, tween: Tween) void {
        self.add(tween) catch {
            tween.fast_forward();
        };
    }

    pub fn build(self: *List) Builder {
        return .{
            .into = self,
        };
    }

    pub const Builder = struct {
        into: *List,
        all_finish_at: u32 = 0,
        last_start_at: u32 = 0,
        mode: enum { seq, par } = .seq,
        ease: Ease = Ease.linear,
        fast_forwarding: bool = false,

        fn append(b: *Builder, t: Tween) void {
            if (b.fast_forwarding) {
                t.fast_forward();
                return;
            }

            var t_ = t;

            switch (b.mode) {
                .seq => {
                    t_.delay += b.all_finish_at;
                    b.all_finish_at = t_.delay + t_.dur;
                    b.last_start_at = t_.delay;
                },
                .par => {
                    t_.delay += b.last_start_at;
                    b.all_finish_at = @max(b.all_finish_at, t_.delay + t_.dur);
                },
            }
            b.into.add(t_) catch {
                p.log("Fast forwarding tween builder", .{});
                b.fast_forwarding = true;
                b.into.finishClear();
                t_.fast_forward();
            };
        }

        pub fn parallel(b: *Builder) void {
            b.mode = .par;
        }

        pub fn sequential(b: *Builder) void {
            b.mode = .seq;
        }

        pub fn of_f32(b: *Builder, target: *f32, from: ?f32, to: f32, dur: u32, delay: u32) void {
            b.append(.{
                .delay = delay,
                .dur = dur,
                .ease = b.ease,
                .target = .{
                    .f32 = .{
                        .target = target,
                        .from = from,
                        .to = to,
                    },
                },
            });
        }

        pub fn of_i32(b: *Builder, target: *i32, from: ?i32, to: i32, dur: u32, delay: u32) void {
            b.append(.{
                .delay = delay,
                .dur = dur,
                .ease = b.ease,
                .target = .{
                    .i32 = .{
                        .target = target,
                        .from = from,
                        .to = to,
                    },
                },
            });
        }

        pub fn of_discrete(b: *Builder, comptime T: type, target: *T, to: T, delay: u32) void {
            comptime std.debug.assert(@sizeOf(T) <= maxDiscreteSize);
            var toArr = [1]u8{0} ** maxDiscreteSize;
            const toArrPtr: *T = @alignCast(std.mem.bytesAsValue(T, &toArr));
            toArrPtr.* = to;
            b.append(.{
                .delay = delay,
                .dur = 0,
                .ease = b.ease,
                .target = .{ .discrete = .{
                    .target = std.mem.asBytes(target),
                    .to = toArr,
                } },
            });
        }

        pub fn of_discrete_ptr(b: *Builder, comptime T: type, noalias target: *T, noalias to: *const T, delay: u32) void {
            std.debug.assert(target != to);
            b.append(.{
                .delay = delay,
                .dur = 0,
                .ease = b.ease,
                .target = .{ .slice = .{
                    .target = std.mem.asBytes(target),
                    .to = std.mem.asBytes(to),
                } },
            });
        }

        pub fn of_sprite_pos(b: *Builder, target: *p.LCDSprite, toX: ?f32, toY: ?f32, dur: u32, delay: u32) void {
            b.append(.{
                .delay = delay,
                .dur = dur,
                .ease = b.ease,
                .target = .{ .spritePos = .{
                    .target = target,
                    .from = null,
                    .to = .{ toX, toY },
                } },
            });
        }

        pub fn of_callback(b: *Builder, func: anytype, arg: anytype, delay: u32) void {
            const Virtual = struct {
                fn impl(ctx: *anyopaque) void {
                    const ctxArg: @TypeOf(arg) = @alignCast(@ptrCast(ctx));
                    func(ctxArg);
                }
            };

            b.append(.{
                .delay = delay,
                .dur = 0,
                .ease = b.ease,
                .target = .{ .callback = .{
                    .func = Virtual.impl,
                    .ctx = arg,
                } },
            });
        }

        pub fn of_none(b: *Builder, dur: u32) void {
            b.append(.{
                .delay = 0,
                .dur = dur,
                .ease = b.ease,
                .target = .none,
            });
        }

        pub fn rewind(b: *Builder, dur: u32) void {
            b.last_start_at -|= dur;
            b.all_finish_at -|= dur;
        }

        pub fn wait(b: *Builder, dur: u32) void {
            switch (b.mode) {
                .seq => {
                    b.last_start_at = b.all_finish_at;
                    b.all_finish_at += dur;
                },
                .par => {
                    b.last_start_at += dur;
                    b.all_finish_at = @max(b.all_finish_at, b.last_start_at);
                },
            }
        }

        pub fn must_fit(b: *const Builder) !void {
            if (b.fast_forwarding) {
                return error.Overflow;
            }
        }
    };
};

pub const Timer = struct {
    dur: u32 = 0,
    started: u32 = 0,

    pub fn start(self: *Timer, dur: u32) void {
        const now = p.playdate.system.getCurrentTimeMilliseconds();
        self.* = .{
            .dur = dur,
            .started = now,
        };
    }

    pub fn check(self: *const Timer) bool {
        const now = p.playdate.system.getCurrentTimeMilliseconds();

        return now -| self.started >= self.dur;
    }
};
