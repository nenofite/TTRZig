const std = @import("std");
const p = @import("global_playdate.zig");

pub const SpriteArena = struct {
    // TODO should it be arena or just a list?
    arena: std.heap.ArenaAllocator,
    sprites: std.ArrayList(*p.LCDSprite),

    pub fn init(parent: std.mem.Allocator) !SpriteArena {
        var arena = std.heap.ArenaAllocator.init(parent);
        errdefer arena.deinit();

        const alloc = arena.allocator();
        const sprites = try std.ArrayList(*p.LCDSprite).initCapacity(alloc, 8);
        errdefer sprites.deinit();

        return .{
            .arena = arena,
            .sprites = sprites,
        };
    }

    pub fn deinit(self: *SpriteArena) void {
        for (self.sprites.items) |i| {
            p.playdate.sprite.freeSprite(i);
        }
        self.arena.deinit();
    }

    pub fn allocator(self: *SpriteArena) std.mem.Allocator {
        return self.arena.allocator();
    }

    pub fn newSprite(self: *SpriteArena) !*p.LCDSprite {
        const sprite = p.playdate.sprite.newSprite() orelse return error.CannotAllocateSprite;
        errdefer p.playdate.sprite.freeSprite(sprite);

        const slot = try self.sprites.addOne();
        slot.* = sprite;
        return sprite;
    }

    pub fn freeSprite(self: *SpriteArena, sprite: *p.LCDSprite) void {
        for (self.sprites.items, 0..) |item, i| {
            if (item == sprite) {
                _ = self.sprites.swapRemove(i);
                p.playdate.sprite.freeSprite(item);
                return;
            }
        }
        p.softFail("Tried to free sprite not in arena");
    }
};
