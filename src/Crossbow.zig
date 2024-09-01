const std = @import("std");
const p = @import("global_playdate.zig");
const tween = @import("tween.zig");
const pat = @import("pattern.zig");
const images = @import("images.zig");
const sounds = @import("sounds.zig");

const SpriteArena = @import("SpriteArena.zig");
const CrossbowBolt = @import("CrossbowBolt.zig");

const Crossbow = @This();

parent: *SpriteArena,
sprite: *p.LCDSprite,
untilNextShot: u8 = shotTiming,

const shotTiming: u8 = 2 * tween.framerate;

pub const Outcome = enum {
    none,
    shoot,
};

pub fn init(parent: *SpriteArena, x: f32, y: f32) !*Crossbow {
    const self = try parent.alloc.create(Crossbow);
    errdefer parent.alloc.destroy(self);

    const sprite = try parent.newSprite(false);
    errdefer parent.freeSprite(sprite);

    self.* = .{
        .parent = parent,
        .sprite = sprite,
    };

    // p.playdate.sprite.setCenter(sprite, 1, 0);
    const img = p.playdate.graphics.getTableBitmap(images.cannonTable, 4) orelse unreachable;
    p.playdate.sprite.moveTo(sprite, x, y);
    p.setZIndex(sprite, .enemies);
    p.playdate.sprite.setImage(sprite, img, .BitmapUnflipped);
    p.playdate.sprite.setUserdata(sprite, @ptrCast(self));
    p.setTag(sprite, .enemy);

    return self;
}

pub fn deinit(self: *Crossbow) void {
    const parent = self.parent;
    parent.freeSprite(self.sprite);
    parent.alloc.destroy(self);
}

pub fn update(self: *Crossbow) Outcome {
    self.untilNextShot -= 1;
    if (self.untilNextShot == 0) {
        self.untilNextShot = shotTiming;
        return .shoot;
    } else {
        return .none;
    }
}
