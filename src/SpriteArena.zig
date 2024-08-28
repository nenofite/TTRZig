const std = @import("std");
const p = @import("global_playdate.zig");
const tween = @import("tween.zig");
const nodes = @import("nodes.zig");

const SpriteArena = @This();

wrappedNode: nodes.AnyNode,

pub fn fromNode(node: nodes.AnyNode) SpriteArena {
    return .{ .wrappedNode = node };
}

pub fn deinit(self: *SpriteArena) void {
    _ = self;
}

pub fn allocator(self: *const SpriteArena) std.mem.Allocator {
    return self.wrappedNode.data.alloc;
}

pub fn newChild(self: *SpriteArena) !*SpriteArena {
    return self;
}

pub fn newSprite(self: *SpriteArena) !*p.LCDSprite {
    return self.wrappedNode.data.newSprite();
}

pub fn freeSprite(self: *SpriteArena, sprite: *p.LCDSprite) void {
    return self.wrappedNode.data.freeSprite(sprite);
}
