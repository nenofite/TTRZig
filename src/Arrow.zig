const std = @import("std");
const p = @import("global_playdate.zig");
const tween = @import("tween.zig");
const pat = @import("pattern.zig");
const perlin = @import("perlin.zig");
const images = @import("images.zig");

const SpriteArena = @import("SpriteArena.zig");

const Arrow = @This();

arena: *SpriteArena,
sprite: *p.LCDSprite,

pub fn init(parentArena: *SpriteArena, x: f32, y: f32) !*@This() {
    const arena = try parentArena.newChild();
    errdefer arena.deinit();

    const self = try arena.alloc.create(@This());
    errdefer arena.alloc.destroy(self);

    self.* = .{
        .arena = arena,
        .sprite = undefined,
    };

    self.sprite = try arena.newSprite();
    errdefer arena.freeSprite(self.sprite);

    self.updateImage();

    // p.playdate.sprite.setSize(sprite, p.WIDTH, p.HEIGHT);
    p.playdate.sprite.setCenter(self.sprite, 0, 0);
    p.playdate.sprite.setZIndex(self.sprite, 1);
    p.playdate.sprite.moveTo(self.sprite, x, y);
    // p.playdate.sprite.setOpaque(sprite, 0);
    p.playdate.sprite.addSprite(self.sprite);

    return self;
}

pub fn deinit(self: *@This()) void {
    self.arena.freeSprite(self.sprite);

    const arena = self.arena;
    arena.alloc.destroy(self);
    arena.deinit();
}

fn updateImage(self: *@This()) void {
    const t = p.playdate.system.getCurrentTimeMilliseconds();
    const phase = @divTrunc(t, 500) % 2;
    const img = p.playdate.graphics.getTableBitmap(images.spritesTable, @intCast(12 + phase)).?;
    p.playdate.sprite.setImage(self.sprite, img, .BitmapUnflipped);
}

pub fn update(self: *@This()) void {
    _ = self.arena.tweens.update();
    self.updateImage();
}
