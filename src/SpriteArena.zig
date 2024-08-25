const std = @import("std");
const p = @import("global_playdate.zig");
const tween = @import("tween.zig");

const SpriteArena = @This();

alloc_inner: TrackedAllocator,
alloc: std.mem.Allocator,
sprites: std.ArrayList(*p.LCDSprite),
tweens: tween.List,

parent: ?*SpriteArena = null,
children: std.ArrayList(*SpriteArena),

pub fn init(parentAlloc: std.mem.Allocator) !*SpriteArena {
    const self = try parentAlloc.create(SpriteArena);
    errdefer parentAlloc.destroy(self);

    self.* = .{
        .alloc_inner = try TrackedAllocator.init(parentAlloc),
        .alloc = undefined,
        .sprites = undefined,
        .tweens = undefined,
        .children = undefined,
    };
    const alloc = self.alloc_inner.allocator();
    self.alloc = alloc;

    self.children = std.ArrayList(*SpriteArena).init(alloc);
    errdefer self.children.deinit();

    self.sprites = try std.ArrayList(*p.LCDSprite).initCapacity(alloc, 8);
    errdefer self.sprites.deinit();

    self.tweens = try tween.List.init(alloc);
    errdefer self.tweens.deinit();

    return self;
}

pub fn deinit(self: *SpriteArena) void {
    self.deinitInner(false);
}

fn deinitInner(self: *SpriteArena, skipParent: bool) void {
    self.tweens.deinit();
    for (self.children.items) |child| {
        child.deinitInner(true);
    }
    self.children.deinit();
    for (self.sprites.items) |i| {
        p.playdate.sprite.freeSprite(i);
    }
    self.sprites.deinit();
    if (!skipParent) if (self.parent) |parent| {
        parent.removeChild(self);
    };
    self.alloc_inner.deinit();
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

    try self.children.append(child);
    errdefer _ = self.children.pop();

    return child;
}

pub fn newNode(self: *SpriteArena, comptime Head: type) !*Head {
    const child = try self.newChild();
    errdefer child.deinit();

    const head = try child.alloc.create(Head);
    errdefer child.alloc.destroy(head);

    head.nodeData = NodeData{
        .arena = child,
        .parent = self,
    };

    return head;
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

pub const AnyNode = struct {
    node: *anyopaque,
    data: *NodeData,
    vtable: *const VTable,

    pub fn update(self: *AnyNode) void {
        self.vtable.update(self.head);
    }

    pub fn deinit(self: *AnyNode) void {
        const arena = self.arena;
        self.vtable.deinit(self.head);
        arena.alloc.destroy(self);
        arena.deinit();
    }

    const VTable = struct {
        update: *const fn (head: *anyopaque) void,
        deinit: *const fn (head: *anyopaque) void,
    };

    pub fn newChild(self: *AnyNode, comptime Head: type) !*Head {
        const child = try Node(Head).init(self);
        errdefer child.deinit();

        try self.data.children.append(child.asAny());
        errdefer _ = self.data.children.pop();

        return child;
    }

    pub fn removeChild(self: *AnyNode, child: AnyNode) void {
        const i = for (self.data.children.items, 0..) |c, ci| {
            if (c.node == child.node) {
                break ci;
            }
        } else {
            p.softFail("Removed child node not in list");
            return;
        };
        _ = self.data.children.swapRemove(i);
    }
};

pub const NodeData = struct {
    arena: *SpriteArena,
    parent: ?*AnyNode,
    children: std.ArrayList(*AnyNode),
};

pub fn Node(comptime Head: type) type {
    return struct {
        pub fn init(parent: *AnyNode) !*Head {
            const arena = try parent.data.arena.newChild();
            errdefer arena.deinit();

            // const head = try arena.alloc.create(Head);
            // errdefer arena.alloc.destroy(head);

            const self = try arena.alloc.create(Head);
            errdefer arena.alloc.destroy(self);

            self.nodeData = NodeData{
                .arena = arena,
                .parent = parent,
            };

            return self;
        }

        pub fn deinit(self: *Head) void {
            const arena: *SpriteArena = self.nodeData.arena;
            self.deinit();
            if (self.nodeData.parent) |parent| {
                parent.removeChild(self.asAny());
                self.nodeData.parent = null;
            }
            arena.alloc.destroy(self);
            arena.deinit();
        }

        pub fn asAny(self: *Head) AnyNode {
            return .{
                .node = self,
                .data = &self.nodeData,
                .vtable = &vtable,
            };
        }

        const vtable = AnyNode.VTable{
            .update = updateVirt,
            .deinit = deinitVirt,
        };

        fn updateVirt(headOpaq: *anyopaque) void {
            const head: *Head = @alignCast(@ptrCast(headOpaq));
            head.update();
        }

        fn deinitVirt(headOpaq: *anyopaque) void {
            const head: *Head = @alignCast(@ptrCast(headOpaq));
            @This().deinit(head);
        }
    };
}

const TrackedAllocator = struct {
    const OpenList = std.DoublyLinkedList([]u8);

    child: std.mem.Allocator,
    open: OpenList,

    pub fn init(child: std.mem.Allocator) !TrackedAllocator {
        return .{
            .child = child,
            .open = .{},
        };
    }

    pub fn deinit(self: *TrackedAllocator) void {
        // self.assertEmpty();
        var it = self.open.first;
        while (it) |node| {
            const next = node.next;
            self.open.remove(node);
            self.child.rawFree(node.data, 0, 0);
            self.child.destroy(node);
            it = next;
        }
    }

    pub fn assertEmpty(self: *const TrackedAllocator) void {
        if (self.open.first == null) return;
        p.fmtPanic("Arena contains {any} non-freed blocks", .{self.open.len});
    }

    fn alloc(ctx: *anyopaque, len: usize, ptr_align: u8, ret_addr: usize) ?[*]u8 {
        _ = ret_addr;
        const self: *TrackedAllocator = @ptrCast(@alignCast(ctx));
        const ptr = self.child.rawAlloc(len, ptr_align, 0) orelse return null;
        const slice = ptr[0..len];
        const slot = self.child.create(OpenList.Node) catch {
            self.child.rawFree(slice, ptr_align, 0);
            return null;
        };
        slot.data = slice;
        self.open.append(slot);
        return ptr;
    }

    fn resize(ctx: *anyopaque, buf: []u8, buf_align: u8, new_len: usize, ret_addr: usize) bool {
        _ = ret_addr;

        const self: *TrackedAllocator = @ptrCast(@alignCast(ctx));
        const node = self.findNode(buf) orelse @panic("Resized something not in allocator");
        if (self.child.rawResize(buf, buf_align, new_len, 0)) {
            node.data = buf.ptr[0..new_len];
            p.log("Successfully resized {any} to {any}", .{ buf.len, new_len });
            return true;
        } else {
            return false;
        }
    }

    fn free(ctx: *anyopaque, buf: []u8, buf_align: u8, ret_addr: usize) void {
        const self: *TrackedAllocator = @ptrCast(@alignCast(ctx));
        const node = self.findNode(buf) orelse @panic("Freed something not in allocator");
        self.open.remove(node);
        self.child.destroy(node);
        self.child.rawFree(buf, buf_align, ret_addr);
    }

    fn findNode(self: *const TrackedAllocator, buf: []u8) ?*OpenList.Node {
        var it = self.open.first;
        while (it) |node| {
            if (node.data.ptr == buf.ptr) {
                if (node.data.len != buf.len) {
                    // hmm
                }
                return node;
            }
            it = node.next;
        }
        return null;
    }

    pub fn allocator(self: *TrackedAllocator) std.mem.Allocator {
        return .{
            .ptr = @ptrCast(self),
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
            },
        };
    }
};
