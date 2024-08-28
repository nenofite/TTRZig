const std = @import("std");
const p = @import("global_playdate.zig");
const tween = @import("tween.zig");

pub const AnyNode = struct {
    node: *anyopaque,
    data: *NodeData,
    vtable: *const VTable,

    pub fn update(self: *AnyNode) void {
        self.vtable.update(self.head);
    }

    pub fn deinit(self: *AnyNode) void {
        // const arena = self.arena;
        self.vtable.deinit(self.head);
        // arena.alloc.destroy(self);
        // arena.deinit();
    }

    const VTable = struct {
        update: *const fn (head: *anyopaque) void,
        deinit: *const fn (head: *anyopaque) void,
    };

    pub fn attachChild(self: *AnyNode, child: AnyNode) !void {
        std.debug.assert(child.data.parent == null);
        try self.data.children.append(child);
        errdefer _ = self.data.children.pop();

        child.data.parent = self;
    }

    pub fn detachChild(self: *AnyNode, child: AnyNode) void {
        std.debug.assert(child.data.parent == self);
        const i = for (self.data.children.items, 0..) |c, ci| {
            if (c.node == child.node) {
                break ci;
            }
        } else {
            p.softFail("Removed child node not in list");
            return;
        };
        _ = self.data.children.swapRemove(i);
        child.data.parent = null;
    }
};

pub const NodeData = struct {
    parent: ?*AnyNode,
    children: std.ArrayList(*AnyNode),

    alloc_inner: TrackedAllocator,
    alloc: std.mem.Allocator,
    sprites: std.ArrayList(*p.LCDSprite),
    tweens: tween.List,

    fn init(self: *NodeData) !void {
        self.alloc_inner = try TrackedAllocator.init(p.allocator);
        errdefer self.alloc_inner.deinit();

        const tweens = try tween.List.init(self.alloc);
        errdefer tweens.deinit();

        self.* = .{
            .parent = null,
            .children = std.ArrayList(*AnyNode).init(self.alloc),
            .sprites = std.ArrayList(*p.LCDSprite).init(self.alloc),
            .tweens = tweens,
            .alloc_inner = self.alloc_inner,
            .alloc = self.alloc,
        };
    }

    fn deinit(self: *NodeData) void {
        self.tweens.finishClear();
        self.tweens.deinit();
        for (self.children.items) |child| {
            child.deinit();
        }
        self.children.deinit();
        for (self.sprites.items) |sprite| {
            p.playdate.sprite.freeSprite(sprite);
        }
        self.sprites.deinit();
        self.alloc_inner.deinit();
    }

    pub fn newSprite(self: *NodeData) !*p.LCDSprite {
        const sprite = p.playdate.sprite.newSprite() orelse return error.CannotAllocateSprite;
        errdefer p.playdate.sprite.freeSprite(sprite);

        try self.sprites.append(sprite);
        errdefer _ = self.sprites.pop();

        return sprite;
    }

    pub fn freeSprite(self: *NodeData, sprite: *p.LCDSprite) void {
        const i = std.mem.indexOfScalar(*p.LCDSprite, self.sprites.items, sprite) orelse {
            p.softFail("Tried to free sprite not in node");
            return;
        };
        _ = self.sprites.swapRemove(i);
        p.playdate.sprite.freeSprite(sprite);
    }
};

pub fn Node(comptime Head: type) type {
    if (!@hasField(Head, "nodeData")) {
        @compileError("Node head must contain `nodeData` field: " ++ @typeName(Head));
    }
    return struct {
        // Allocates the node, initializes its NodeData, and attaches it to the
        // parent. This does not call `Head.init`; instead, this function should
        // be called by that function
        pub fn init(parentOpt: ?*AnyNode) !*Head {
            const parentAlloc = p.allocator;

            const node = try parentAlloc.create(Head);
            errdefer parentAlloc.destroy(node);

            const nodeData: *NodeData = &node.nodeData;

            try nodeData.init(parentAlloc);
            errdefer nodeData.deinit();

            if (parentOpt) |parent| {
                try parent.attachChild(node.asAny());
            }

            return node;
        }

        // Removes this node from its parent, deinits the NodeData, and finally
        // frees this memory. This should be the final call of `Head.deinit`
        pub fn deinit(self: *Head) void {
            const nodeData: *NodeData = &self.nodeData;
            if (nodeData.parent) |parent| {
                parent.detachChild(self.asAny());
            }
            std.debug.assert(nodeData.parent == null);
            nodeData.deinit();
            p.allocator.destroy(self);
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
            head.deinit();
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
