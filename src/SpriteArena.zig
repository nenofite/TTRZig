const std = @import("std");
const p = @import("global_playdate.zig");

const SpriteArena = @This();

// alloc_inner: *TrackedAllocator,
alloc: std.mem.Allocator,
sprites: std.ArrayList(*p.LCDSprite),

parent: ?*SpriteArena = null,
children: std.ArrayList(*SpriteArena),

pub fn init(alloc: std.mem.Allocator) !*SpriteArena {
    const self = try alloc.create(SpriteArena);
    errdefer alloc.destroy(self);

    const sprites = try std.ArrayList(*p.LCDSprite).initCapacity(alloc, 8);
    errdefer sprites.deinit();

    self.* = .{
        .alloc = alloc,
        .sprites = sprites,
        .children = std.ArrayList(*SpriteArena).init(alloc),
    };

    return self;
}

pub fn deinit(self: *SpriteArena) void {
    self.deinitInner(false);
}

fn deinitInner(self: *SpriteArena, skipParent: bool) void {
    for (self.children.items) |child| {
        child.deinitInner(true);
    }
    for (self.sprites.items) |i| {
        p.playdate.sprite.freeSprite(i);
    }
    self.sprites.deinit();
    if (!skipParent) if (self.parent) |parent| {
        parent.removeChild(self);
    };
    // self.arena.deinit();
}

fn removeChild(self: *SpriteArena, child: *SpriteArena) void {
    const i = std.mem.indexOfScalar(*SpriteArena, self.children.items, child) orelse {
        p.softFail("Not a child of this arena");
        return;
    };
    _ = self.children.swapRemove(i);
    child.parent = undefined;
}

pub fn allocator(self: *SpriteArena) std.mem.Allocator {
    return self.alloc;
}

pub fn newChild(self: *SpriteArena) !*SpriteArena {
    const child = try init(self.alloc);
    errdefer self.alloc.destroy(child);

    child.parent = self;

    const childSlot = try self.children.addOne();
    errdefer _ = self.children.pop();
    childSlot.* = child;

    return child;
}

pub fn newSprite(self: *SpriteArena) !*p.LCDSprite {
    const sprite = p.playdate.sprite.newSprite() orelse return error.CannotAllocateSprite;
    errdefer p.playdate.sprite.freeSprite(sprite);

    const slot = try self.sprites.addOne();
    slot.* = sprite;
    return sprite;
}

pub fn freeSprite(self: *SpriteArena, sprite: *p.LCDSprite) void {
    const i = std.mem.indexOfScalar(*p.LCDSprite, self.sprites.items, sprite) orelse {
        p.softFail("Tried to free sprite not in arena");
        return;
    };
    _ = self.sprites.swapRemove(i);
    p.playdate.sprite.freeSprite(sprite);
}

// const TrackedAllocator = struct {
//     const OpenList = std.DoublyLinkedList(*anyopaque);

//     child: std.mem.Allocator,
//     open: OpenList,

//     pub fn init(child: std.mem.Allocator) TrackedAllocator {
//         return .{
//             .child = child,
//             .open = .{},
//         };
//     }

//     pub fn deinit(self: *TrackedAllocator) void {
//         var it = self.open.first;
//         while (it) |node| {
//             self.child.destroy(node.data);
//             const ptr: [*]u8 = @ptrCast(@alignCast(node.data));
//             self.child.rawFree(ptr[0..1], undefined, 0);
//             it = node.next;
//         }
//     }

//     fn alloc(ctx: *anyopaque, len: usize, ptr_align: u8, ret_addr: usize) ?[*]u8 {
//         _ = ret_addr;
//         const self: *TrackedAllocator = @ptrCast(@alignCast(ctx));
//         // const ptr = self.child.alloc(u8, len) catch return null;
//         const ptr = self.child.rawAlloc(len, ptr_align, 0) orelse return null;
//         const slot = self.child.create(OpenList.Node) catch {
//             self.child.rawFree(ptr[0..len], ptr_align, 0);
//             // self.child.free(ptr);
//             return null;
//         };
//         slot.data = @ptrCast(ptr);
//         self.open.append(slot);
//         return ptr;
//     }

//     fn resize(ctx: *anyopaque, buf: []u8, buf_align: u8, new_len: usize, ret_addr: usize) bool {
//         const self: *TrackedAllocator = @ptrCast(@alignCast(ctx));
//         return self.child.rawResize(buf, buf_align, new_len, ret_addr);
//     }

//     fn free(ctx: *anyopaque, buf: []u8, buf_align: u8, ret_addr: usize) void {
//         const self: *TrackedAllocator = @ptrCast(@alignCast(ctx));
//         var it = self.open.first;
//         while (it) |node| {
//             if (node.data == buf.ptr) {
//                 self.open.remove(node);
//                 self.child.destroy(node);
//                 break;
//             }
//             it = node.next;
//         } else {
//             @panic("Freed something not in allocator");
//         }
//         self.child.rawFree(buf, buf_align, ret_addr);
//     }

//     pub fn allocator(self: *TrackedAllocator) std.mem.Allocator {
//         return .{
//             .ptr = @ptrCast(self),
//             .vtable = &.{
//                 .alloc = alloc,
//                 .resize = resize,
//                 .free = free,
//             },
//         };
//     }
// };
