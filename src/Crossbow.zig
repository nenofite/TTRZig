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
tweens: tween.List,

shouldFire: bool = false,
nextImage: ?*p.LCDBitmap = null,

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
        .tweens = undefined,
    };

    self.tweens = try tween.List.init(parent.alloc);
    errdefer self.tweens.deinit();

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
    const active = self.tweens.update();
    if (!active) self.tweenShot();

    if (self.nextImage) |img| {
        p.playdate.sprite.setImage(self.sprite, img, .BitmapUnflipped);
        self.nextImage = null;
    }

    if (self.shouldFire) {
        self.shouldFire = false;
        return .shoot;
    } else {
        return .none;
    }
}

fn tweenShot(self: *Crossbow) void {
    const main = p.playdate.graphics.getTableBitmap(images.cannonTable, 4) orelse unreachable;
    const draw = p.playdate.graphics.getTableBitmap(images.cannonTable, 5) orelse unreachable;
    const shoot = p.playdate.graphics.getTableBitmap(images.cannonTable, 6) orelse unreachable;

    var b = self.tweens.build();
    b.of_discrete(?*p.LCDBitmap, &self.nextImage, main, 0);
    b.wait(1500);

    b.of_discrete(?*p.LCDBitmap, &self.nextImage, draw, 0);
    b.wait(500);

    b.of_discrete(?*p.LCDBitmap, &self.nextImage, shoot, 0);
    b.of_discrete(bool, &self.shouldFire, true, 0);
    b.wait(200);

    b.of_discrete(?*p.LCDBitmap, &self.nextImage, main, 0);
}
