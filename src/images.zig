const std = @import("std");
const p = @import("global_playdate.zig");

pub var spritesTable: *p.LCDBitmapTable = undefined;

pub fn init() void {
    spritesTable = p.playdate.graphics.loadBitmapTable("images/sprites", null) orelse @panic("Could not load sprites images");
}
