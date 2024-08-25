const std = @import("std");
const p = @import("global_playdate.zig");
const tween = @import("tween.zig");
const pat = @import("pattern.zig");
const images = @import("images.zig");
const tags = @import("tags.zig");

const SpriteArena = @import("SpriteArena.zig");

const Coin = @This();

nodeData: SpriteArena.NodeData,
sprite: *p.LCDSprite,

pub fn init(parent: *SpriteArena, x: f32, y: f32) !*Coin {
    const self = try parent.newNode(Coin);
    errdefer parent.freeNode(self);

    const sprite = try self.nodeData.arena.newSprite();
    errdefer self.nodeData.arena.freeSprite(sprite);

    p.playdate.sprite.setTag(sprite, tags.coin);
    p.playdate.sprite.setCollideRect(sprite, .{ .x = 0, .y = 0, .width = 8, .height = 8 });

    self.* = .{
        .nodeData = self.nodeData,
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
