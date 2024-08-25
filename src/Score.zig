const std = @import("std");
const p = @import("global_playdate.zig");
const tween = @import("tween.zig");
const pat = @import("pattern.zig");
const images = @import("images.zig");
const sounds = @import("sounds.zig");

const SpriteArena = @import("SpriteArena.zig");

const Score = @This();

const numDigits = 3;
const digitSize = 20;

arena: *SpriteArena,
sprite: *p.LCDSprite,

prevScore: u32 = 0,
score: u32 = 0,
scoreF: f32 = 0,

const margin = 3;

pub fn init(parentArena: *SpriteArena, z: p.Z) !*Score {
    const arena = try parentArena.newChild();
    errdefer arena.deinit();

    const self = try arena.alloc.create(Score);
    errdefer arena.alloc.destroy(self);

    const sprite = try arena.newSprite();
    errdefer arena.freeSprite(sprite);

    p.playdate.sprite.setCenter(sprite, 1, 0);
    p.playdate.sprite.moveTo(sprite, p.WIDTH, p.HEIGHT / 2);
    p.playdate.sprite.setSize(sprite, 3 * digitSize + 2 * margin, digitSize + 2 * margin);
    p.setZIndex(sprite, z);
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
    self.tweenScore();
    const prevScoreF = self.scoreF;
    _ = self.arena.tweens.update();
    // self.scoreF = std.math.lerp(self.scoreF, @as(f32, @floatFromInt(self.score)), 0.05);
    const roundCmp = @round(self.scoreF) - @round(prevScoreF);
    if (roundCmp > 0) {
        sounds.playOnceVaried(sounds.score, 0.025);
    } else if (roundCmp < 0) {
        sounds.playOnceVaried(sounds.loseCoin, 0.025);
    }
    p.playdate.sprite.markDirty(self.sprite);
}

fn tweenScore(self: *Score) void {
    if (self.score == self.prevScore) return;

    self.prevScore = self.score;
    self.arena.tweens.cancelClear();
    var b = self.arena.tweens.build();
    b.ease = .{ .curve = .cubic, .ends = .out };
    b.of_f32(&self.scoreF, null, @floatFromInt(self.score), 1000, 0);
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
        // @intFromPtr(&pat.dot_2),
    );
    p.playdate.graphics.setDrawMode(.DrawModeWhiteTransparent);
    var digits = [1]f32{0} ** numDigits;
    digitRoll(self.scoreF, &digits);
    var digitX = x + margin + (numDigits - 1) * digitSize;
    for (digits) |digit| {
        drawDigit(digitX, y + margin, digit);
        digitX -= digitSize;
    }
    p.playdate.graphics.setDrawMode(.DrawModeCopy);
    p.playdate.graphics.drawRect(
        @intFromFloat(bounds.x),
        @intFromFloat(bounds.y),
        @intFromFloat(bounds.width),
        @intFromFloat(bounds.height),
        @intFromEnum(p.LCDSolidColor.ColorBlack),
    );
    p.playdate.graphics.drawRect(
        @intFromFloat(bounds.x + 1),
        @intFromFloat(bounds.y + 1),
        @intFromFloat(bounds.width - 2),
        @intFromFloat(bounds.height - 2),
        @intFromPtr(&pat.gray),
    );
    p.playdate.graphics.drawRect(
        @intFromFloat(bounds.x + 2),
        @intFromFloat(bounds.y + 2),
        @intFromFloat(bounds.width - 4),
        @intFromFloat(bounds.height - 4),
        @intFromEnum(p.LCDSolidColor.ColorBlack),
    );
}

fn digitRoll(original: f32, digitsLE: []f32) void {
    // First place flat digits
    var divided = original;
    for (digitsLE) |*digit| {
        digit.* = @trunc(@mod(divided, 10));
        divided /= 10;
    }
    // Now go from least to most significant adding roll
    const sub = @mod(original * 10, 10) / 10;
    for (digitsLE) |*digit| {
        digit.* += sub;
        if (digit.* < 9) {
            break;
        }
    }
}
