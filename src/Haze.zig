const std = @import("std");
const p = @import("global_playdate.zig");
const tween = @import("tween.zig");
const pat = @import("pattern.zig");
const perlin = @import("perlin.zig");

const SpriteArena = @import("SpriteArena.zig");

const haze = &([8]u8{ 0x80, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0 } ++ pat.alphaMask);

const bubble1 = &([8]u8{ 0xFF, 0xDD, 0xFF, 0x77, 0xFF, 0xDD, 0xFF, 0x77 } ++ pat.alphaMask);
const bubble2 = &([8]u8{ 0xFF, 0xDD, 0xFF, 0xFF, 0xFF, 0xDD, 0xFF, 0xFF } ++ pat.alphaMask);
const bubble3 = &([8]u8{ 0xFF, 0xDF, 0xFF, 0xFF, 0xFF, 0xFD, 0xFF, 0xFF } ++ pat.alphaMask);

const baseRadius = 100;

fn drawBubble(bx: i32, by: i32, r: i32) void {
    if (r > 0) {
        const r1 = r;
        const r2 = @max(0, r - 8);
        const r3 = @max(0, r - 16);
        const r4 = @max(0, r - 24);
        p.playdate.graphics.fillEllipse(bx - r1, by - r1, r1 * 2, r1 * 2, 0, 360, @intFromPtr(bubble1));
        p.playdate.graphics.fillEllipse(bx - r2, by - r2, r2 * 2, r2 * 2, 0, 360, @intFromPtr(bubble2));
        p.playdate.graphics.fillEllipse(bx - r3, by - r3, r3 * 2, r3 * 2, 0, 360, @intFromPtr(bubble3));
        p.playdate.graphics.fillEllipse(bx - r4, by - r4, r4 * 2, r4 * 2, 0, 360, @intFromEnum(p.LCDSolidColor.ColorWhite));
    }
    if (r < 20) {
        p.playdate.graphics.fillEllipse(bx, by, 20, 20, 0, 360, @intFromEnum(p.LCDSolidColor.ColorWhite));
    }
}

arena: *SpriteArena,
sprite: *p.LCDSprite,
spriteImg: *p.LCDBitmap,
bubbleRadius: i32 = 0,

pub fn init(parentArena: *SpriteArena) !*@This() {
    const arena = try parentArena.newChild();
    errdefer arena.deinit();

    const self = try arena.alloc.create(@This());
    errdefer arena.alloc.destroy(self);

    const sprite = try arena.newSprite();
    errdefer arena.freeSprite(sprite);

    const spriteImg = p.playdate.graphics.newBitmap(p.WIDTH, p.HEIGHT, @intFromEnum(p.LCDSolidColor.ColorWhite)) orelse
        return error.OutOfMemory;
    errdefer p.playdate.graphics.freeBitmap(spriteImg);

    self.* = .{
        .arena = arena,
        .sprite = sprite,
        .spriteImg = spriteImg,
    };

    // p.playdate.sprite.setSize(sprite, p.WIDTH, p.HEIGHT);
    p.playdate.sprite.setImage(sprite, spriteImg, .BitmapUnflipped);
    p.playdate.sprite.setCenter(sprite, 0, 0);
    p.playdate.sprite.setZIndex(sprite, 5);
    p.playdate.sprite.setOpaque(sprite, 0);
    p.playdate.sprite.setIgnoresDrawOffset(sprite, 1);
    _ = p.playdate.sprite.setDrawMode(sprite, .DrawModeWhiteTransparent);
    // p.playdate.sprite.setDrawFunction(sprite, drawSprite);
    p.playdate.sprite.addSprite(sprite);

    self.ignite();

    return self;
}

pub fn deinit(self: *@This()) void {
    p.playdate.graphics.freeBitmap(self.spriteImg);
    self.arena.freeSprite(self.sprite);

    const arena = self.arena;
    arena.alloc.destroy(self);
    arena.deinit();
}

pub fn update(self: *@This(), focus: [2]i32) void {
    _ = self.arena.tweens.update();
    const t = p.playdate.system.getCurrentTimeMilliseconds();
    const noiseOffset: f32 = @as(f32, @floatFromInt(t)) / 500;
    const flicker = perlin.noise(f32, .{ .x = noiseOffset }) * 0.1 + 0.9;
    const r = @as(i32, @intFromFloat(@as(f32, @floatFromInt(self.bubbleRadius)) * flicker));
    self.drawImage(focus, r);
    p.playdate.sprite.markDirty(self.sprite);
}

fn ignite(self: *@This()) void {
    var b = self.arena.tweens.build();
    b.ease = .{ .curve = .cubic, .ends = .out };
    b.of_i32(&self.bubbleRadius, 0, baseRadius, 500, 0);
}

fn drawImage(self: *@This(), focus: [2]i32, r: i32) void {
    p.playdate.graphics.pushContext(self.spriteImg);
    defer p.playdate.graphics.popContext();

    p.playdate.graphics.fillRect(0, 0, p.WIDTH, p.HEIGHT, @intFromPtr(haze));
    drawBubble(focus[0], focus[1], r);
}

// fn drawSprite(sprite: ?*p.LCDSprite, bounds: p.PDRect, drawrect: p.PDRect) callconv(.C) void {
//     _ = bounds;
//     _ = drawrect;

// }
