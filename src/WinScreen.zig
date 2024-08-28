const std = @import("std");
const p = @import("global_playdate.zig");
const panic_handler = @import("panic_handler.zig");
const tween = @import("tween.zig");
const pat = @import("pattern.zig");
const icons = @import("icons.zig");
const sounds = @import("sounds.zig");
const images = @import("images.zig");
const tags = @import("tags.zig");
const text_sprite = @import("text_sprite.zig");

const SpriteArena = @import("SpriteArena.zig");
const Score = @import("Score.zig");
const MainScreen = @import("MainScreen.zig");

const WinScreen = @This();

arena: *SpriteArena,
levelNumber: u8,
backdrop: *p.LCDSprite,
title: *p.LCDSprite,
titleImg: *p.LCDBitmap,
endedWithScore: u32,

score: *Score,

main: ?*MainScreen,

backdropPattern: *const pat.Pattern = &pat.transparent,
prevBackdropPattern: *const pat.Pattern = &pat.transparent,

// const fadeSequence = [_]*const pat.Pattern{
//     &pat.blackTransparent(pat.invert(pat.dot_2)),
//     &pat.blackTransparent(pat.darkgray),
//     &pat.blackTransparent(pat.darkgray_1),
//     &pat.blackTransparent(pat.gray_5),
//     &pat.blackTransparent(pat.lightgray),
//     &pat.blackTransparent(pat.white),
// };

pub fn init(main: *MainScreen) !*WinScreen {
    const arena = try SpriteArena.init(p.allocator);
    errdefer arena.deinit();

    const self = try arena.alloc.create(WinScreen);
    errdefer arena.alloc.destroy(self);

    self.* = .{
        .arena = arena,
        .backdrop = undefined,
        .title = undefined,
        .titleImg = undefined,
        .score = undefined,
        .main = main,
        .endedWithScore = main.score.score,
        .levelNumber = main.levelNumber,
    };

    self.backdrop = try arena.newSprite();
    errdefer arena.freeSprite(self.backdrop);

    p.playdate.sprite.setBounds(self.backdrop, .{ .x = 0, .y = 0, .width = p.WIDTH, .height = p.HEIGHT });
    p.playdate.sprite.setOpaque(self.backdrop, 0);
    // _ = p.playdate.sprite.setDrawMode(self.backdrop, .DrawModeBlackTransparent);
    p.playdate.sprite.setUserdata(self.backdrop, self);
    p.playdate.sprite.setDrawFunction(self.backdrop, drawBackdrop);
    p.playdate.sprite.setIgnoresDrawOffset(self.backdrop, 1);
    p.setZIndex(self.backdrop, .winBackdrop);
    p.playdate.sprite.addSprite(self.backdrop);

    self.titleImg = try text_sprite.makeTextBmp("Glorious!", images.mans, 4);
    errdefer p.playdate.graphics.freeBitmap(self.titleImg);

    self.title = try arena.newSprite();
    errdefer arena.freeSprite(self.title);

    p.playdate.sprite.setImage(self.title, self.titleImg, .BitmapUnflipped);
    p.playdate.sprite.setCenter(self.title, 0.5, 0.5);
    p.playdate.sprite.moveTo(self.title, p.WIDTH / 2, p.HEIGHT + 50);
    p.playdate.sprite.setIgnoresDrawOffset(self.title, 1);
    p.setZIndex(self.title, .winTitle);
    p.playdate.sprite.addSprite(self.title);

    self.score = try Score.init(arena, .winScore);
    errdefer self.score.deinit();

    p.playdate.sprite.setCenter(self.score.sprite, 0.5, 0);
    p.playdate.sprite.moveTo(self.score.sprite, p.WIDTH / 2, p.HEIGHT + 50);

    self.entranceTween();

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
    if (self.main) |main| {
        _ = main.update();
    }
    _ = self.arena.tweens.update();
    self.score.update();

    if (self.backdropPattern != self.prevBackdropPattern) {
        self.prevBackdropPattern = self.backdropPattern;
        p.playdate.sprite.markDirty(self.backdrop);
    }

    if (self.main == null and p.getButtonState().released.a) {
        self.arena.tweens.finishClear();
        self.loadNextLevel() catch unreachable;
        self.exitTween();
    }
}

fn clearMain(self: *WinScreen) void {
    if (self.main) |main| {
        main.deinit();
        self.main = null;
    }
}

fn loadNextLevel(self: *WinScreen) !void {
    self.clearMain();
    self.main = try MainScreen.init(self.levelNumber + 1);
}

fn entranceTween(self: *WinScreen) void {
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

    b.of_callback(clearMain, self, 0);

    b.wait(step);

    b.ease = .{ .curve = .cubic, .ends = .out };
    b.of_sprite_pos(self.title, p.WIDTH / 2, p.HEIGHT / 2, 400, 0);
    b.mode = .par;
    b.wait(100);
    b.of_sprite_pos(self.score.sprite, p.WIDTH / 2, p.HEIGHT - 80, 400, 0);

    b.mode = .seq;
    b.of_discrete(u32, &self.score.score, self.endedWithScore, 0);
    // b.of_f32(&self.score.score, 0, self.endedWithScore, 1000, 0);
}

fn exitTween(self: *WinScreen) void {
    const step = 100;
    var b = self.arena.tweens.build();
    b.of_discrete(*const pat.Pattern, &self.backdropPattern, &comptime pat.blackTransparent(pat.white), 0);
    b.wait(step);
    b.of_discrete(*const pat.Pattern, &self.backdropPattern, &comptime pat.blackTransparent(pat.lightgray), 0);
    b.wait(step);
    b.of_discrete(*const pat.Pattern, &self.backdropPattern, &comptime pat.blackTransparent(pat.gray_5), 0);
    b.wait(step);
    b.of_discrete(*const pat.Pattern, &self.backdropPattern, &comptime pat.blackTransparent(pat.darkgray_1), 0);
    b.wait(step);
    b.of_discrete(*const pat.Pattern, &self.backdropPattern, &comptime pat.blackTransparent(pat.darkgray), 0);
    b.wait(step);
    b.of_discrete(*const pat.Pattern, &self.backdropPattern, &comptime pat.blackTransparent(pat.invert(pat.dot_2)), 0);

    b.of_callback(clearMain, self, 0);
}

fn drawBackdrop(sprite: ?*p.LCDSprite, bounds: p.PDRect, drawrect: p.PDRect) callconv(.C) void {
    _ = bounds;
    const self: *WinScreen = @alignCast(@ptrCast(p.playdate.sprite.getUserdata(sprite).?));
    p.playdate.graphics.fillRect(
        @intFromFloat(drawrect.x),
        @intFromFloat(drawrect.y),
        @intFromFloat(drawrect.width),
        @intFromFloat(drawrect.height),
        @intFromPtr(self.backdropPattern),
    );
}
