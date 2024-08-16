const std = @import("std");
const p = @import("global_playdate.zig");

pub var spritesTable: *p.LCDBitmapTable = undefined;
pub var dungeonTable: *p.LCDBitmapTable = undefined;

pub fn init() void {
    spritesTable = loadTableOrPanic("images/sprites");
    dungeonTable = loadTableOrPanic("images/dungeon-inv");
}

fn loadTableOrPanic(comptime path: []const u8) *p.LCDBitmapTable {
    var errOpt: [*c]const u8 = null;
    const resultOpt = p.playdate.graphics.loadBitmapTable(path.ptr, &errOpt);
    if (errOpt) |err| {
        p.fmtPanic("Could not load {s}: {s}", .{ path, err });
    }
    const result = resultOpt orelse {
        p.fmtPanic("Could not load {s}: Got null", .{path});
    };
    return result;
}
