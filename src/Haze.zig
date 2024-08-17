const std = @import("std");
const p = @import("global_playdate.zig");
const tween = @import("tween.zig");
const pat = @import("pattern.zig");

const SpriteArena = @import("sprite_arena.zig").SpriteArena;

const haze = &([8]u8{ 0x80, 0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0 } ++ pat.alphaMask);

const bubble1 = &([8]u8{ 0xFF, 0xDD, 0xFF, 0x77, 0xFF, 0xDD, 0xFF, 0x77 } ++ pat.alphaMask);
const bubble2 = &([8]u8{ 0xFF, 0xDD, 0xFF, 0xFF, 0xFF, 0xDD, 0xFF, 0xFF } ++ pat.alphaMask);
const bubble3 = &([8]u8{ 0xFF, 0xDF, 0xFF, 0xFF, 0xFF, 0xFD, 0xFF, 0xFF } ++ pat.alphaMask);

fn drawBubble(bx: i32, by: i32, r: i32) void {
    if (r > 0) {
        const r1 = r;
        const r2 = @max(0, r - 8);
        const r3 = @max(0, r - 16);
        const r4 = @max(0, r - 24);
        p.playdate.graphics.fillEllipse(bx, by, r1, r1, 0, 360, @intFromPtr(bubble1));
        p.playdate.graphics.fillEllipse(bx, by, r2, r2, 0, 360, @intFromPtr(bubble2));
        p.playdate.graphics.fillEllipse(bx, by, r3, r3, 0, 360, @intFromPtr(bubble3));
        p.playdate.graphics.fillEllipse(bx, by, r4, r4, 0, 360, @intFromEnum(p.LCDSolidColor.ColorWhite));
    }
    if (r < 20) {
        p.playdate.graphics.fillEllipse(bx, by, 20, 20, 0, 360, @intFromEnum(p.LCDSolidColor.ColorWhite));
    }
}

arena: *SpriteArena,
sprite: *p.LCDSprite,
spriteImg: *p.LCDBitmap,

pub fn init(arena: *SpriteArena) !@This() {
    const sprite = try arena.newSprite();
    errdefer arena.freeSprite(sprite);

    const spriteImg = p.playdate.graphics.newBitmap(p.WIDTH, p.HEIGHT, @intFromEnum(p.LCDSolidColor.ColorWhite)) orelse
        return error.OutOfMemory;
    errdefer p.playdate.graphics.freeBitmap(spriteImg);

    // p.playdate.sprite.setSize(sprite, p.WIDTH, p.HEIGHT);
    p.playdate.sprite.setImage(sprite, spriteImg, .BitmapUnflipped);
    p.playdate.sprite.setCenter(sprite, 0, 0);
    p.playdate.sprite.setZIndex(sprite, 5);
    p.playdate.sprite.setIgnoresDrawOffset(sprite, 1);
    _ = p.playdate.sprite.setDrawMode(sprite, .DrawModeWhiteTransparent);
    // p.playdate.sprite.setDrawFunction(sprite, drawSprite);
    p.playdate.sprite.addSprite(sprite);

    return .{
        .arena = arena,
        .sprite = sprite,
        .spriteImg = spriteImg,
    };
}

pub fn deinit(self: *@This()) void {
    p.playdate.graphics.freeBitmap(self.spriteImg);
    self.arena.freeSprite(self.sprite);
}

pub fn update(self: *@This()) void {
    self.drawImage();
    p.playdate.sprite.markDirty(self.sprite);
}

fn drawImage(self: *@This()) void {
    p.playdate.graphics.pushContext(self.spriteImg);
    defer p.playdate.graphics.popContext();

    p.playdate.graphics.fillRect(0, 0, p.WIDTH, p.HEIGHT, @intFromPtr(haze));
    drawBubble(p.WIDTH / 2, p.HEIGHT / 2, 50);
}

// fn drawSprite(sprite: ?*p.LCDSprite, bounds: p.PDRect, drawrect: p.PDRect) callconv(.C) void {
//     _ = bounds;
//     _ = drawrect;

// }
