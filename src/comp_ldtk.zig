const std = @import("std");
const ldtk = @import("LDtk.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    if (args.len < 3) {
        std.debug.print("Usage: {s} INPUT OUTPUT", .{args[0]});
        std.process.exit(1);
    }

    const inputPath = args[1];
    const outputPath = args[2];

    var inputFile = try std.fs.cwd().openFile(inputPath, .{});
    defer inputFile.close();
    var outputFile = try std.fs.cwd().createFile(outputPath, .{});
    defer outputFile.close();
    const rawFile = try inputFile.readToEndAlloc(alloc, 1024 * 1024 * 1024);
    defer alloc.free(rawFile);

    const ct = loadLevel(alloc, rawFile);
    const result = try std.fmt.allocPrint(alloc, "count is: {any}\nchao\n", .{ct});
    defer alloc.free(result);

    try outputFile.writeAll(result);
    std.debug.print("Completed write!", .{});
}

fn loadLevel(parentAlloc: std.mem.Allocator, rawFile: []const u8) i32 {
    var arena = std.heap.ArenaAllocator.init(parentAlloc);
    defer arena.deinit();
    const alloc = arena.allocator();

    var root = ldtk.parse(alloc, rawFile) catch @panic("Couldn't parse levels.ldtk");
    defer root.deinit();

    const level: *ldtk.Level = forLevel: for (root.root.levels) |*l| {
        if (std.mem.eql(u8, l.identifier, "Level_0")) {
            break :forLevel l;
        }
    } else {
        @panic("Could not find Level_0");
    };
    var layerCount: i32 = 0;
    if (level.layerInstances) |layers| {
        for (layers) |_| {
            layerCount += 1;
        }
    }

    return layerCount;
}
