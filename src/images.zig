const std = @import("std");
const p = @import("global_playdate.zig");

pub var spritesTable: *p.LCDBitmapTable = undefined;
pub var dungeonTable: *p.LCDBitmapTable = undefined;
pub var blowTable: *p.LCDBitmapTable = undefined;
pub var cannonTable: *p.LCDBitmapTable = undefined;
pub var heartsTable: *p.LCDBitmapTable = undefined;
pub var digits: *p.LCDBitmap = undefined;
pub var geo: *p.LCDFont = undefined;
pub var mans: *p.LCDFont = undefined;

pub fn init() void {
    spritesTable = loadTableOrPanic("images/sprites");
    dungeonTable = loadTableOrPanic("images/dungeon-inv");
    blowTable = loadTableOrPanic("images/blow");
    cannonTable = loadTableOrPanic("images/cannon");
    heartsTable = loadTableOrPanic("images/hearts");
    digits = loadBitmapOrPanic("images/digits");

    geo = loadFont("fonts/geo");
    mans = loadFont("fonts/mans");
}

fn loadBitmapOrPanic(path: [:0]const u8) *p.LCDBitmap {
    var errOpt: [*c]const u8 = null;
    const resultOpt = p.playdate.graphics.loadBitmap(path.ptr, &errOpt);
    if (errOpt) |err| {
        p.fmtPanic("Could not load {s}: {s}", .{ path, err });
    }
    const result = resultOpt orelse {
        p.fmtPanic("Could not load {s}: Got null", .{path});
    };
    return result;
}

fn loadTableOrPanic(path: [:0]const u8) *p.LCDBitmapTable {
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

fn loadFont(path: [:0]const u8) *p.LCDFont {
    var errOpt: [*c]const u8 = null;
    const fontOpt = p.playdate.graphics.loadFont(path.ptr, &errOpt);
    if (errOpt) |err| {
        p.fmtPanic("Can't load {s}: {s}", .{ path, err });
    }
    return fontOpt orelse p.fmtPanic("Can't load {s}", .{path});
}
