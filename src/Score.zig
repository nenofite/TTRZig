const std = @import("std");
const p = @import("global_playdate.zig");
const tween = @import("tween.zig");
const pat = @import("pattern.zig");
const images = @import("images.zig");

const SpriteArena = @import("SpriteArena.zig");

const Score = @This();

const digits = 3;
const digitSize = 20;

arena: *SpriteArena,
sprite: *p.LCDSprite,

score: u32 = 0,
scoreF: f32 = 0,

pub fn init(parentArena: *SpriteArena) !*Score {
    const arena = try parentArena.newChild();
    errdefer arena.deinit();

    const self = try arena.alloc.create(Score);
    errdefer arena.alloc.destroy(self);

    const sprite = try arena.newSprite();
    errdefer arena.freeSprite(sprite);

    p.playdate.sprite.setCenter(sprite, 1, 0);
    p.playdate.sprite.moveTo(sprite, p.WIDTH, p.HEIGHT / 2);
    p.playdate.sprite.setSize(sprite, 3 * digitSize, digitSize);
    p.playdate.sprite.setZIndex(sprite, 9);
    p.playdate.sprite.setIgnoresDrawOffset(sprite, 1);
    p.playdate.sprite.addSprite(sprite);
    p.playdate.sprite.setUserdata(sprite, @ptrCast(self));
    p.playdate.sprite.setDrawFunction(sprite, drawCallback);

    self.* = .{
        .arena = arena,
        .sprite = sprite,
    };

    return self;
}

pub fn deinit(self: *Score) void {
    const arena = self.arena;
    arena.freeSprite(self.sprite);
    arena.alloc.destroy(self);
    arena.deinit();
}

pub fn update(self: *Score) void {
    self.scoreF = std.math.lerp(self.scoreF, @as(f32, @floatFromInt(self.score)), 0.9);
    p.playdate.sprite.markDirty(self.sprite);
}

fn drawDigit(x: i32, y: i32, digit: f32) void {
    const img = images.digits;
    p.playdate.graphics.setClipRect(x, y, digitSize, digitSize);
    defer p.playdate.graphics.clearClipRect();
    p.playdate.graphics.drawBitmap(img, x, y + @as(i32, @intFromFloat(digit * -digitSize)), .BitmapUnflipped);
}

fn drawCallback(sprite: ?*p.LCDSprite, bounds: p.PDRect, _: p.PDRect) callconv(.C) void {
    const self: *Score = @alignCast(@ptrCast(p.playdate.sprite.getUserdata(sprite.?).?));

    const x: i32 = @intFromFloat(bounds.x);
    const y: i32 = @intFromFloat(bounds.y);

    p.playdate.graphics.fillRect(
        @intFromFloat(bounds.x),
        @intFromFloat(bounds.y),
        @intFromFloat(bounds.width),
        @intFromFloat(bounds.height),
        @intFromEnum(p.LCDSolidColor.ColorWhite),
    );
    p.playdate.graphics.drawRect(
        @intFromFloat(bounds.x + 1),
        @intFromFloat(bounds.y + 1),
        @intFromFloat(bounds.width - 2),
        @intFromFloat(bounds.height - 2),
        @intFromEnum(p.LCDSolidColor.ColorBlack),
    );
    var remaining = self.scoreF;
    var digitX = x + (digits - 1) * digitSize;
    for (0..digits) |_| {
        const digit = @mod(remaining, 10);
        drawDigit(digitX, y, digit);
        remaining /= 10;
        digitX -= digitSize;
    }
}
