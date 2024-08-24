const std = @import("std");
const p = @import("global_playdate.zig");
const panic_handler = @import("panic_handler.zig");
const tween = @import("tween.zig");
const pat = @import("pattern.zig");
const icons = @import("icons.zig");
const sounds = @import("sounds.zig");
const images = @import("images.zig");
const tags = @import("tags.zig");

const SpriteArena = @import("SpriteArena.zig");
const Score = @import("Score.zig");

const WinScreen = @This();

arena: *SpriteArena,
backdrop: *p.LCDSprite,
title: *p.LCDSprite,

backdropPattern: *const pat.Pattern = &pat.black,

pub fn init(parent: *SpriteArena) !*WinScreen {
    const self = try parent.newChild(WinScreen);
    errdefer self.arena.deinit();

    self.* = .{
        .arena = self.arena,
        .backdrop = undefined,
        .title = undefined,
    };

    self.backdrop = try self.arena.newSprite();
    errdefer self.arena.freeSprite(self.backdrop);

    self.title = try self.arena.newSprite();
    errdefer self.arena.freeSprite(self.title);

    self.setupBackdrop();

    return self;
}

pub fn deinit(self: *WinScreen) void {
    const arena = self.arena;
    arena.freeSprite(self.backdrop);
    arena.freeSprite(self.title);
    arena.alloc.destroy(self);
    arena.deinit();
}

pub fn update(self: *WinScreen) !void {
    _ = self.arena.tweens.update();
    p.playdate.sprite.markDirty(self.backdrop);
}

fn setupBackdrop(self: *WinScreen) void {
    p.playdate.sprite.setBounds(self.backdrop, .{ .x = 0, .y = 0, .width = p.WIDTH, .height = p.HEIGHT });
    p.playdate.sprite.setOpaque(self.backdrop, 0);
    _ = p.playdate.sprite.setDrawMode(self.backdrop, .DrawModeBlackTransparent);
    p.playdate.sprite.setUserdata(self.backdrop, self);
    p.playdate.sprite.setDrawFunction(self.backdrop, drawBackdrop);
    p.playdate.sprite.addSprite(self.backdrop);

    var b = self.arena.tweens.build();
    b.wait(100);
    b.of_discrete(*const pat.Pattern, &self.backdropPattern, &comptime pat.invert(pat.dot_2), 0);
    b.wait(100);
    b.of_discrete(*const pat.Pattern, &self.backdropPattern, &pat.darkgray, 0);
    b.wait(100);
    b.of_discrete(*const pat.Pattern, &self.backdropPattern, &pat.darkgray_1, 0);
    b.wait(100);
    b.of_discrete(*const pat.Pattern, &self.backdropPattern, &pat.gray_5, 0);
    b.wait(100);
    b.of_discrete(*const pat.Pattern, &self.backdropPattern, &pat.lightgray, 0);
    b.wait(100);
    b.of_discrete(*const pat.Pattern, &self.backdropPattern, &pat.white, 0);
    // b.of_discrete(*const pat.Pattern, &self.backdropPattern, &pat.darkgray_2, 0);
}

fn drawBackdrop(sprite: ?*p.LCDSprite, bounds: p.PDRect, drawrect: p.PDRect) callconv(.C) void {
    _ = bounds;
    _ = drawrect;
    const self: *WinScreen = @alignCast(@ptrCast(p.playdate.sprite.getUserdata(sprite).?));
    p.playdate.graphics.fillRect(0, 0, p.WIDTH, p.HEIGHT, @intFromPtr(self.backdropPattern));
}
