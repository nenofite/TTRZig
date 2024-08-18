const std = @import("std");
const p = @import("global_playdate.zig");
const tween = @import("tween.zig");
const pat = @import("pattern.zig");
const images = @import("images.zig");

const SpriteArena = @import("SpriteArena.zig");

const Coin = @This();

arena: *SpriteArena,
sprite: *p.LCDSprite,

pub fn init(parent: *SpriteArena, x: f32, y: f32) !*Coin {
    const arena = try parent.newChild();
    errdefer arena.deinit();

    const self = try arena.alloc.create(Coin);
    errdefer arena.alloc.destroy(self);

    const sprite = try arena.newSprite();
    errdefer arena.freeSprite(sprite);

    self.* = .{
        .arena = arena,
        .sprite = sprite,
    };

    self.setPhaseImg();
    p.playdate.sprite.moveTo(sprite, x, y);
    p.playdate.sprite.addSprite(sprite);

    return self;
}

pub fn deinit(self: *Coin) void {
    const arena = self.arena;
    arena.freeSprite(self.sprite);
    arena.alloc.destroy(self);
    arena.deinit();
}

fn setPhaseImg(self: *Coin) void {
    const now = p.playdate.system.getCurrentTimeMilliseconds();
    const phase = (now / 100) % 4;
    const phaseImg = p.playdate.graphics.getTableBitmap(images.dungeonTable, @intCast(10 + phase)) orelse @panic("Cannot get coin sprite");
    p.playdate.sprite.setImage(self.sprite, phaseImg, .BitmapUnflipped);
}

pub fn update(self: *Coin) void {
    self.setPhaseImg();
}
