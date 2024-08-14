const std = @import("std");
const p = @import("global_playdate.zig");

pub var heartsTable: *p.LCDBitmapTable = undefined;

pub fn init() void {
    heartsTable = p.playdate.graphics.loadBitmapTable("images/hearts", null) orelse @panic("Could not load hearts images");
}
