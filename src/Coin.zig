const std = @import("std");
const p = @import("global_playdate.zig");
const tween = @import("tween.zig");
const pat = @import("pattern.zig");
const images = @import("images.zig");
const tags = @import("tags.zig");
const nodes = @import("nodes.zig");

const Coin = @This();

nodeData: nodes.NodeData,
sprite: *p.LCDSprite,

pub fn init(parent: nodes.AnyNode, x: f32, y: f32) !*Coin {
    const self = try nodes.Node(@This()).init(parent);
    errdefer nodes.Node(@This()).deinit(self);

    const sprite = try self.nodeData.newSprite();
    errdefer self.nodeData.freeSprite(sprite);

    p.playdate.sprite.setTag(sprite, tags.coin);
    p.playdate.sprite.setCollideRect(sprite, .{ .x = 0, .y = 0, .width = 8, .height = 8 });

    self.* = .{
        .nodeData = self.nodeData,
        .sprite = sprite,
    };

    self.setPhaseImg();
    p.playdate.sprite.moveTo(sprite, x, y);
    p.setZIndex(sprite, .coins);
    p.playdate.sprite.addSprite(sprite);

    return self;
}

pub fn deinit(self: *Coin) void {
    self.nodeData.freeSprite(self.sprite);
    nodes.Node(@This()).deinit(self);
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
