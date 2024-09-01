const std = @import("std");
const p = @import("global_playdate.zig");
const tween = @import("tween.zig");
const pat = @import("pattern.zig");
const images = @import("images.zig");
const sounds = @import("sounds.zig");

const SpriteArena = @import("SpriteArena.zig");

const CrossbowBolt = @This();

parent: *SpriteArena,
sprite: *p.LCDSprite,

const Outcome = enum {
    none,
    remove,
};

pub fn init(parent: *SpriteArena, x: f32, y: f32) !*CrossbowBolt {
    const self = try parent.alloc.create(CrossbowBolt);
    errdefer parent.alloc.destroy(self);

    const sprite = try parent.newSprite(false);
    errdefer parent.freeSprite(sprite);

    self.* = .{
        .parent = parent,
        .sprite = sprite,
    };

    self.updateImage();

    // p.playdate.sprite.setCenter(sprite, 1, 0);
    p.playdate.sprite.moveTo(sprite, x, y);
    p.setZIndex(sprite, .projectiles);
    p.playdate.sprite.setUserdata(sprite, @ptrCast(self));
    p.setTag(sprite, .projectile);
    p.playdate.sprite.setCollisionResponseFunction(sprite, collisionResponse);
    p.playdate.sprite.setCollideRect(sprite, .{ .x = 7, .y = 3, .width = 2, .height = 10 });

    return self;
}

pub fn deinit(self: *CrossbowBolt) void {
    const parent = self.parent;
    parent.freeSprite(self.sprite);
    parent.alloc.destroy(self);
}

fn updateImage(self: *CrossbowBolt) void {
    const phase = 7 + p.playdate.system.getCurrentTimeMilliseconds() / 100 % 2;
    std.debug.assert(7 <= phase and phase <= 8);
    const img = p.playdate.graphics.getTableBitmap(images.cannonTable, @intCast(phase)).?;
    p.playdate.sprite.setImage(self.sprite, img, .BitmapUnflipped);
}

pub fn update(self: *CrossbowBolt) Outcome {
    const speed = 50.0 / tween.framerateF;

    self.updateImage();

    var x: f32 = 0;
    var y: f32 = 0;
    p.playdate.sprite.getPosition(self.sprite, &x, &y);
    y -= speed;
    const collisionsOpt = p.moveWithCollisions(self.sprite, &x, &y);
    if (collisionsOpt) |collisions| {
        defer _ = p.playdate.system.realloc(collisions.ptr, 0);

        for (collisions) |collision| {
            const other = collision.other orelse continue;
            const otherTag = p.getTag(other);
            if (otherTag == .wall) {
                return .remove;
            }
        }
    }

    return .none;
}

fn collisionResponse(self: ?*p.LCDSprite, otherOpt: ?*p.LCDSprite) callconv(.C) p.SpriteCollisionResponseType {
    _ = self;
    const other = otherOpt orelse return .CollisionTypeSlide;
    const otherTag = p.getTag(other);
    switch (otherTag) {
        .wall => return .CollisionTypeFreeze,
        else => return .CollisionTypeOverlap,
    }
}
