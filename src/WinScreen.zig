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
const MainScreen = @import("MainScreen.zig");

const WinScreen = @This();

arena: *SpriteArena,
backdrop: *p.LCDSprite,
title: *p.LCDSprite,

prev: ?*MainScreen,

backdropPattern: *const pat.Pattern = &pat.transparent,

pub fn init(parent: *SpriteArena, prev: *MainScreen) !*WinScreen {
    const arena = try parent.newChild();
    errdefer arena.deinit();

    const self = try arena.alloc.create(WinScreen);
    errdefer arena.alloc.destroy(self);

    self.* = .{
        .arena = arena,
        .backdrop = undefined,
        .title = undefined,
        .prev = prev,
    };

    self.backdrop = try arena.newSprite();
    errdefer arena.freeSprite(self.backdrop);

    self.title = try arena.newSprite();
    errdefer arena.freeSprite(self.title);

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

pub fn update(self: *WinScreen) void {
    if (self.prev) |prev| {
        try prev.update();
    }
    const active = self.arena.tweens.update();
    p.playdate.sprite.markDirty(self.backdrop);
    if (!active) {
        if (self.prev) |prev| {
            prev.deinit();
            self.prev = null;
        }
    }
}

fn setupBackdrop(self: *WinScreen) void {
    p.playdate.sprite.setBounds(self.backdrop, .{ .x = 0, .y = 0, .width = p.WIDTH, .height = p.HEIGHT });
    p.playdate.sprite.setOpaque(self.backdrop, 0);
    // _ = p.playdate.sprite.setDrawMode(self.backdrop, .DrawModeBlackTransparent);
    p.playdate.sprite.setUserdata(self.backdrop, self);
    p.playdate.sprite.setDrawFunction(self.backdrop, drawBackdrop);
    p.playdate.sprite.setIgnoresDrawOffset(self.backdrop, 1);
    p.playdate.sprite.setZIndex(self.backdrop, 100);
    p.playdate.sprite.addSprite(self.backdrop);

    const step = 100;
    var b = self.arena.tweens.build();
    b.wait(step);
    b.of_discrete(*const pat.Pattern, &self.backdropPattern, &comptime pat.blackTransparent(pat.invert(pat.dot_2)), 0);
    b.wait(step);
    b.of_discrete(*const pat.Pattern, &self.backdropPattern, &comptime pat.blackTransparent(pat.darkgray), 0);
    b.wait(step);
    b.of_discrete(*const pat.Pattern, &self.backdropPattern, &comptime pat.blackTransparent(pat.darkgray_1), 0);
    b.wait(step);
    b.of_discrete(*const pat.Pattern, &self.backdropPattern, &comptime pat.blackTransparent(pat.gray_5), 0);
    b.wait(step);
    b.of_discrete(*const pat.Pattern, &self.backdropPattern, &comptime pat.blackTransparent(pat.lightgray), 0);
    b.wait(step);
    b.of_discrete(*const pat.Pattern, &self.backdropPattern, &comptime pat.blackTransparent(pat.white), 0);
    // b.of_discrete(*const pat.Pattern, &self.backdropPattern, &comptime pat.blackTransparent(pat.darkgray_2), 0);
}

fn drawBackdrop(sprite: ?*p.LCDSprite, bounds: p.PDRect, drawrect: p.PDRect) callconv(.C) void {
    _ = bounds;
    _ = drawrect;
    const self: *WinScreen = @alignCast(@ptrCast(p.playdate.sprite.getUserdata(sprite).?));
    p.playdate.graphics.fillRect(0, 0, p.WIDTH, p.HEIGHT, @intFromPtr(self.backdropPattern));
}
