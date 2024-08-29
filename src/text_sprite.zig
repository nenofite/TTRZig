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

const debugDraw = false;

fn maybeDebugBackground() p.LCDColor {
    return if (debugDraw)
        @intFromPtr(&pat.dline_4)
    else
        @intFromEnum(p.LCDSolidColor.ColorClear);
}

pub fn makeTextBmp(text: []const u8, font: *p.LCDFont, margin: i32) !*p.LCDBitmap {
    p.playdate.graphics.setFont(font);

    const height = p.playdate.graphics.getFontHeight(font);
    if (height <= 0) unreachable;

    const width = p.playdate.graphics.getTextWidth(font, text.ptr, text.len, .UTF8Encoding, 0);
    if (width <= 0) unreachable;

    const bmp = p.playdate.graphics.newBitmap(
        width + margin * 2,
        @as(i32, @intCast(height)) + margin * 2,
        maybeDebugBackground(),
    ) orelse return error.OutOfMemory;
    errdefer p.playdate.graphics.freeBitmap(bmp);

    if (debugDraw) p.log("Text bitmap {}x{} for text: {s}", .{ width, height, text });

    p.playdate.graphics.pushContext(bmp);
    defer p.playdate.graphics.popContext();

    _ = p.playdate.graphics.drawText(text.ptr, text.len, .UTF8Encoding, margin, margin);
    return bmp;
}

pub const IconOrText = union(enum) {
    icon: icons.Icon,
    text: []const u8,
};

pub fn makeMixedBmp(line: []const IconOrText, font: *p.LCDFont, margin: i32) !*p.LCDBitmap {
    p.playdate.graphics.setFont(font);
    const fontHeight = p.playdate.graphics.getFontHeight(font);
    std.debug.assert(fontHeight > 0);

    const bounds = measureMixed(line, font, margin);
    const image = p.playdate.graphics.newBitmap(
        bounds[0],
        bounds[1],
        maybeDebugBackground(),
    ) orelse return error.OutOfMemory;
    errdefer p.playdate.graphics.freeBitmap(image);

    p.playdate.graphics.pushContext(image);
    defer p.playdate.graphics.popContext();

    const textY = @divTrunc(bounds[1] - fontHeight, 2);
    const iconY = @divTrunc(bounds[1] - icons.size, 2);

    var x: i32 = margin;
    for (line) |piece| {
        switch (piece) {
            .icon => |icon| {
                const iconImg = icons.get(icon);
                p.playdate.graphics.drawBitmap(iconImg, x, iconY, .BitmapUnflipped);
                x += icons.size;
            },
            .text => |text| {
                const textWidth = p.playdate.graphics.drawText(text.ptr, text.len, .UTF8Encoding, x, textY);
                std.debug.assert(textWidth > 0);
                x += textWidth;
            },
        }
    }

    return image;
}

fn measureMixed(line: []const IconOrText, font: *p.LCDFont, margin: i32) [2]i32 {
    const fontHeight = p.playdate.graphics.getFontHeight(font);
    std.debug.assert(fontHeight > 0);
    const height = @max(fontHeight, icons.size) + margin * 2;

    var width: i32 = margin * 2;
    for (line) |piece| {
        switch (piece) {
            .icon => {
                width += icons.size;
            },
            .text => |text| {
                const textWidth = p.playdate.graphics.getTextWidth(font, text.ptr, text.len, .UTF8Encoding, 0);
                std.debug.assert(textWidth > 0);
                width += textWidth;
            },
        }
    }
    return .{ width, height };
}
