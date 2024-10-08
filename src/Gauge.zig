const std = @import("std");
const p = @import("global_playdate.zig");
const tween = @import("tween.zig");
const pat = @import("pattern.zig");

const SpriteArena = @import("SpriteArena.zig");

const Gauge = @This();

arena: *SpriteArena,
sprite: *p.LCDSprite,
img: *p.LCDBitmap,
baseImg: *p.LCDBitmap,

ticks: u8,
tickLength: i32,

minAngle: f32,
maxAngle: f32,
angle: f32,

radius: i32,

needleColor: p.LCDSolidColor = .ColorBlack,
heavyTicks: HeavyTicks,

pub const HeavyTicks = struct {
    min: bool = true,
    mid: bool = false,
    max: bool = true,
};

pub const Options = struct {
    ticks: u8,
    tickLength: i32,
    minAngle: f32,
    maxAngle: f32,
    cx: f32,
    cy: f32,
    radius: i32,
    z: p.Z,
    heavyTicks: HeavyTicks = .{},
};

pub fn init(parentArena: *SpriteArena, options: Options) !*Gauge {
    const arena = try parentArena.newChild();
    errdefer arena.deinit();

    const self = try arena.alloc.create(Gauge);
    errdefer arena.alloc.destroy(self);

    const sprite = try arena.newSprite(true);
    errdefer arena.freeSprite(sprite);

    const img = p.playdate.graphics.newBitmap(
        options.radius * 2,
        options.radius * 2,
        @intFromEnum(p.LCDSolidColor.ColorClear),
    ) orelse return error.OutOfMemory;
    errdefer p.playdate.graphics.freeBitmap(img);

    const baseImg = p.playdate.graphics.newBitmap(
        options.radius * 2,
        options.radius * 2,
        @intFromEnum(p.LCDSolidColor.ColorClear),
    ) orelse return error.OutOfMemory;
    errdefer p.playdate.graphics.freeBitmap(baseImg);

    p.playdate.sprite.setImage(sprite, img, .BitmapUnflipped);
    p.playdate.sprite.moveTo(sprite, options.cx, options.cy);
    p.setZIndex(sprite, options.z);
    p.playdate.sprite.addSprite(sprite);

    const startAngle = options.minAngle;

    self.* = .{
        .arena = arena,
        .sprite = sprite,
        .img = img,
        .baseImg = baseImg,
        .ticks = options.ticks,
        .tickLength = options.tickLength,
        .minAngle = options.minAngle,
        .maxAngle = options.maxAngle,
        .angle = startAngle,
        .radius = options.radius,
        .heavyTicks = options.heavyTicks,
    };

    self.drawBaseImg();

    return self;
}

pub fn deinit(self: *Gauge) void {
    const arena = self.arena;
    p.playdate.graphics.freeBitmap(self.img);
    p.playdate.graphics.freeBitmap(self.baseImg);
    arena.freeSprite(self.sprite);
    arena.alloc.destroy(self);
    arena.deinit();
}

pub fn setFraction(self: *Gauge, frac: f32) void {
    const fracClamped = std.math.clamp(frac, 0, 1);
    const angleTarget = std.math.lerp(self.minAngle, self.maxAngle, fracClamped);
    const f = 0.05;
    self.angle = std.math.lerp(self.angle, angleTarget, f);
}

pub fn update(self: *Gauge) void {
    self.draw();
    p.playdate.sprite.markDirty(self.sprite);
}

fn draw(self: *Gauge) void {
    p.playdate.graphics.pushContext(self.img);
    defer p.playdate.graphics.popContext();

    p.playdate.graphics.clear(@intFromEnum(p.LCDSolidColor.ColorClear));

    p.playdate.graphics.drawBitmap(self.baseImg, 0, 0, .BitmapUnflipped);
    self.drawNeedle(self.angle);
    self.drawPin();
}

fn drawBaseImg(self: *Gauge) void {
    p.playdate.graphics.pushContext(self.baseImg);
    defer p.playdate.graphics.popContext();

    p.playdate.graphics.clear(@intFromEnum(p.LCDSolidColor.ColorClear));

    self.drawBase();

    if (self.ticks > 0) {
        const tickDelta = (self.maxAngle - self.minAngle) / @as(f32, @floatFromInt(self.ticks - 1));
        const midIdx = @divTrunc(self.ticks, 2);
        for (1..self.ticks - 1) |t| {
            const heavy = self.heavyTicks.mid and t == midIdx;
            self.drawTick(self.minAngle + @as(f32, @floatFromInt(t)) * tickDelta, heavy);
        }
        self.drawTick(self.minAngle, self.heavyTicks.min);
        self.drawTick(self.maxAngle, self.heavyTicks.max);
    }

    self.drawFrame();
}

fn drawTick(self: *Gauge, angle: f32, heavy: bool) void {
    const center = self.radius;
    const inner = polar(@as(f32, @floatFromInt(self.radius - self.tickLength)), angle);
    const outer = polar(@as(f32, @floatFromInt(self.radius)), angle);
    p.playdate.graphics.drawLine(
        center + @as(i32, @intFromFloat(inner[0])),
        center + @as(i32, @intFromFloat(inner[1])),
        center + @as(i32, @intFromFloat(outer[0])),
        center + @as(i32, @intFromFloat(outer[1])),
        if (heavy) 3 else 1,
        @intCast(@intFromEnum(self.needleColor)),
    );
}

fn drawNeedle(self: *Gauge, angle: f32) void {
    const center = self.radius;
    const outer = polar(@as(f32, @floatFromInt(self.radius)) * 0.8, angle);
    p.playdate.graphics.drawLine(
        center,
        center,
        center + @as(i32, @intFromFloat(outer[0])),
        center + @as(i32, @intFromFloat(outer[1])),
        3,
        @intCast(@intFromEnum(self.needleColor)),
    );
}

fn drawPin(self: *Gauge) void {
    const center = self.radius;
    const outerR = 3;
    const innerR = 1;
    p.playdate.graphics.fillEllipse(
        center - outerR,
        center - outerR,
        outerR * 2,
        outerR * 2,
        0,
        360,
        @intFromEnum(p.LCDSolidColor.ColorBlack),
    );
    p.playdate.graphics.fillEllipse(
        center - innerR,
        center - innerR,
        innerR * 2,
        innerR * 2,
        0,
        360,
        @intFromEnum(p.LCDSolidColor.ColorWhite),
    );
}

fn drawBase(self: *Gauge) void {
    const center = self.radius;
    const radius = self.radius;
    p.playdate.graphics.fillEllipse(
        center - radius,
        center - radius,
        radius * 2,
        radius * 2,
        0,
        360,
        @intFromPtr(&pat.dot_2),
    );
}

fn drawFrame(self: *Gauge) void {
    const center = self.radius;
    const radius = self.radius;
    p.playdate.graphics.drawEllipse(
        center - radius,
        center - radius + 1,
        radius * 2,
        radius * 2,
        3,
        0,
        360,
        @intFromEnum(p.LCDSolidColor.ColorBlack),
    );
    p.playdate.graphics.drawEllipse(
        center - radius,
        center - radius,
        radius * 2,
        radius * 2,
        1,
        0,
        360,
        @intFromEnum(p.LCDSolidColor.ColorWhite),
    );
}

fn polar(r: f32, angle: f32) [2]f32 {
    const rad = std.math.degreesToRadians(angle);
    return .{
        std.math.cos(rad) * r,
        std.math.sin(rad) * r,
    };
}
