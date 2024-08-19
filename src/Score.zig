const std = @import("std");
const p = @import("global_playdate.zig");
const tween = @import("tween.zig");
const pat = @import("pattern.zig");
const images = @import("images.zig");

const SpriteArena = @import("SpriteArena.zig");

const Score = @This();

arena: *SpriteArena,
sprite: *p.LCDSprite,

score: u32 = 0,
prevScore: u32 = 0,

pub fn init(parentArena: *SpriteArena) !*Score {
    const arena = try parentArena.newChild();
    errdefer arena.deinit();

    const self = try arena.alloc.create(Score);
    errdefer arena.alloc.destroy(self);

    const sprite = try arena.newSprite();
    errdefer arena.freeSprite(sprite);

    p.playdate.sprite.setCenter(sprite, 1, 0);
    p.playdate.sprite.moveTo(sprite, p.WIDTH, p.HEIGHT / 2);
    p.playdate.sprite.setSize(sprite, 30, 16);
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
    if (self.score == self.prevScore) return;
    self.prevScore = self.score;
    p.playdate.sprite.markDirty(self.sprite);
}

fn drawCallback(sprite: ?*p.LCDSprite, bounds: p.PDRect, _: p.PDRect) callconv(.C) void {
    const self: *Score = @alignCast(@ptrCast(p.playdate.sprite.getUserdata(sprite.?).?));

    var textBuf = [1]u8{0} ** 8;
    const text = std.fmt.bufPrintZ(&textBuf, "{d:0>3}", .{self.score}) catch "999";

    // _ = bounds;
    // p.playdate.graphics.fillRect(
    //     @intFromFloat(bounds.x),
    //     @intFromFloat(bounds.y),
    //     @intFromFloat(bounds.width),
    //     @intFromFloat(bounds.height),
    //     @intFromEnum(p.LCDSolidColor.ColorWhite),
    // );
    // p.playdate.graphics.clear(@intFromEnum(p.LCDSolidColor.ColorWhite));
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
    // p.playdate.graphics.clear(@intFromPtr(&pat.brick_1));
    p.playdate.graphics.setFont(images.geo);
    _ = p.playdate.graphics.drawText(
        text.ptr,
        text.len,
        .UTF8Encoding,
        @intFromFloat(bounds.x + 4),
        @intFromFloat(bounds.y),
    );
}
