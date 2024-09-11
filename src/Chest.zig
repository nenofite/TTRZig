const std = @import("std");
const p = @import("global_playdate.zig");
const tween = @import("tween.zig");
const pat = @import("pattern.zig");
const perlin = @import("perlin.zig");
const images = @import("images.zig");

const SpriteArena = @import("SpriteArena.zig");

const Chest = @This();

arena: *SpriteArena,
sprite: *p.LCDSprite,
opened: bool = false,

const OpenOutcome = enum {
    treasure,
    alreadyOpened,
};

pub fn init(parentArena: *SpriteArena, x: f32, y: f32) !*Chest {
    const arena = try parentArena.newChild();
    errdefer arena.deinit();

    const self = try arena.alloc.create(Chest);
    errdefer arena.alloc.destroy(self);

    self.* = .{
        .arena = arena,
        .sprite = undefined,
    };

    self.sprite = try arena.newSprite(false);
    errdefer arena.freeSprite(self.sprite);

    self.updateImage();

    p.playdate.sprite.setCenter(self.sprite, 0, 0);
    p.playdate.sprite.setCollideRect(self.sprite, .{ .x = 0, .y = 6, .width = 16, .height = 10 });
    p.setZIndex(self.sprite, .treasures);
    p.setTag(self.sprite, .chest);
    p.playdate.sprite.setUserdata(self.sprite, self);
    p.playdate.sprite.moveTo(self.sprite, x, y);

    return self;
}

pub fn deinit(self: *Chest) void {
    self.arena.freeSprite(self.sprite);

    const arena = self.arena;
    arena.alloc.destroy(self);
    arena.deinit();
}

pub fn open(self: *Chest) OpenOutcome {
    if (self.opened) {
        return .alreadyOpened;
    } else {
        self.opened = true;
        self.updateImage();
        return .treasure;
    }
}

fn updateImage(self: *Chest) void {
    const idx: i32 = if (self.opened) 11 else 9;
    const img = p.playdate.graphics.getTableBitmap(images.cannonTable, idx).?;
    p.playdate.sprite.setImage(self.sprite, img, .BitmapUnflipped);
}

pub fn update(self: *Chest) void {
    _ = self.arena.tweens.update();
    self.updateImage();
}
