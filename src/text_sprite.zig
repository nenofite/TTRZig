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

pub fn makeTextBmp(text: []const u8, font: *p.LCDFont, margin: i32) !*p.LCDBitmap {
    const height = p.playdate.graphics.getFontHeight(font);
    if (height <= 0) unreachable;

    const width = p.playdate.graphics.getTextWidth(font, text.ptr, text.len, .UTF8Encoding, 0);
    if (width <= 0) unreachable;

    const bmp = p.playdate.graphics.newBitmap(
        width + margin * 2,
        @as(i32, @intCast(height)) + margin * 2,
        @intFromEnum(p.LCDSolidColor.ColorClear),
    ) orelse return error.OutOfMemory;
    errdefer p.playdate.graphics.freeBitmap(bmp);

    p.playdate.graphics.pushContext(bmp);
    defer p.playdate.graphics.popContext();

    p.playdate.graphics.setFont(font);
    _ = p.playdate.graphics.drawText(text.ptr, text.len, .UTF8Encoding, margin, margin);
    return bmp;
}
