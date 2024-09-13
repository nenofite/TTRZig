const std = @import("std");
const p = @import("global_playdate.zig");
const tween = @import("tween.zig");
const pat = @import("pattern.zig");
const images = @import("images.zig");
const sounds = @import("sounds.zig");

const SpriteArena = @import("SpriteArena.zig");

const HealthBar = @This();

parentArena: *SpriteArena,
sprites: []*p.LCDSprite,

maxHealth: u32 = startingHealth,
prevHealth: u32 = startingHealth,
health: u32 = startingHealth,

const startingHealth = 3;

pub fn init(parentArena: *SpriteArena) !*HealthBar {
    const self = try parentArena.alloc.create(HealthBar);
    errdefer parentArena.alloc.destroy(self);

    self.* = .{
        .parentArena = parentArena,
        .sprites = undefined,
    };

    self.sprites = try parentArena.alloc.alloc(*p.LCDSprite, self.maxHealth);
    errdefer parentArena.alloc.free(self.sprites);

    const heartImg = p.playdate.graphics.getTableBitmap(images.heartsTable, 0).?;

    const y = p.HEIGHT - 1;
    for (self.sprites, 0..) |*slot, i| {
        const heart = try parentArena.newSprite(true);
        slot.* = heart;
        p.setZIndex(heart, .score);
        p.playdate.sprite.setImage(heart, heartImg, .BitmapUnflipped);
        p.playdate.sprite.setCenter(heart, 0, 1);
        _ = p.playdate.sprite.setDrawMode(heart, .DrawModeInverted);
        const x = @as(f32, @floatFromInt(i)) * 14 + 1;
        p.playdate.sprite.moveTo(heart, x, y);
    }

    return self;
}

pub fn deinit(self: *HealthBar) void {
    const alloc = self.parentArena.alloc;
    for (self.sprites) |heart| {
        self.parentArena.freeSprite(heart);
    }
    alloc.destroy(self);
}

pub fn update(self: *HealthBar) void {
    if (self.prevHealth != self.health) {
        self.prevHealth = self.health;

        const onImg = p.playdate.graphics.getTableBitmap(images.heartsTable, 0).?;
        const offImg = p.playdate.graphics.getTableBitmap(images.heartsTable, 1).?;
        for (0..self.sprites.len) |i| {
            const revI = self.sprites.len - i - 1;
            const heart = self.sprites[revI];
            const on = revI + 1 <= self.health;
            const img = if (on) onImg else offImg;
            p.playdate.sprite.setImage(heart, img, .BitmapUnflipped);
        }
    }
}
