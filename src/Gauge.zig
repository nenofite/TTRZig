const std = @import("std");
const p = @import("global_playdate.zig");
const tween = @import("tween.zig");
const pat = @import("pattern.zig");

const SpriteArena = @import("SpriteArena.zig");

const Gauge = @This();

arena: *SpriteArena,
sprite: *p.LCDSprite,
img: *p.LCDBitmap,

ticks: u8,

minAngle: f32,
maxAngle: f32,
angle: f32,

radius: i32,

needleColor: p.LCDSolidColor = .ColorBlack,

pub const Options = struct {
    ticks: u8 = 8,
    minAngle: f32,
    maxAngle: f32,
    cx: f32,
    cy: f32,
    radius: i32,
    zIndex: i16,
};

pub fn init(parentArena: *SpriteArena, options: Options) !*Gauge {
    const arena = try parentArena.newChild();
    errdefer arena.deinit();

    const self = try arena.alloc.create(Gauge);
    errdefer arena.alloc.destroy(self);

    const sprite = try arena.newSprite();
    errdefer arena.freeSprite(sprite);

    const img = p.playdate.graphics.newBitmap(
        options.radius * 2,
        options.radius * 2,
        @intFromEnum(p.LCDSolidColor.ColorClear),
    ) orelse return error.OutOfMemory;
    errdefer p.playdate.graphics.freeBitmap(img);

    p.playdate.sprite.setImage(sprite, img, .BitmapUnflipped);
    p.playdate.sprite.moveTo(sprite, options.cx, options.cy);
    p.playdate.sprite.setZIndex(sprite, options.zIndex);
    p.playdate.sprite.setIgnoresDrawOffset(sprite, 1);
    p.playdate.sprite.addSprite(sprite);

    self.* = .{
        .arena = arena,
        .sprite = sprite,
        .img = img,
        .ticks = options.ticks,
        .minAngle = options.minAngle,
        .maxAngle = options.maxAngle,
        .angle = 0,
        .radius = options.radius,
    };

    return self;
}

pub fn deinit(self: *Gauge) void {
    const arena = self.arena;
    p.playdate.graphics.freeBitmap(self.img);
    arena.freeSprite(self.sprite);
    arena.alloc.destroy(self);
    arena.deinit();
}

pub fn update(self: *Gauge) void {
    self.draw();
    p.playdate.sprite.markDirty(self.sprite);
}

fn draw(self: *Gauge) void {
    p.playdate.graphics.pushContext(self.img);
    defer p.playdate.graphics.popContext();

    self.drawBase();

    if (self.ticks > 0) {
        const tickDelta = (self.maxAngle - self.minAngle) / @as(f32, @floatFromInt(self.ticks - 1));
        for (1..self.ticks - 2) |t| {
            self.drawTick(@as(f32, @floatFromInt(t)) * tickDelta);
        }
    }

    self.drawNeedle(self.angle);
    self.drawPin();
    self.drawFrame();
}

fn drawTick(self: *Gauge, angle: f32) void {
    const center = self.radius;
    const inner = polar(@as(f32, @floatFromInt(self.radius)) * 0.6, angle);
    const outer = polar(@as(f32, @floatFromInt(self.radius)), angle);
    p.playdate.graphics.drawLine(
        center + @as(i32, @intFromFloat(inner[0])),
        center + @as(i32, @intFromFloat(inner[1])),
        center + @as(i32, @intFromFloat(outer[0])),
        center + @as(i32, @intFromFloat(outer[1])),
        1,
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
        @intFromPtr(&pat.lightgray),
    );
}

fn drawFrame(self: *Gauge) void {
    const center = self.radius;
    const radius = self.radius;
    p.playdate.graphics.drawEllipse(
        center - radius,
        center - radius,
        radius * 2,
        radius * 2,
        5,
        0,
        360,
        @intFromEnum(p.LCDSolidColor.ColorBlack),
    );
    p.playdate.graphics.drawEllipse(
        center - radius,
        center - radius - 1,
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
