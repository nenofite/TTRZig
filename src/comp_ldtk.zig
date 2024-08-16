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

    const result = try loadLevel(alloc, rawFile);
    // const result = try std.fmt.allocPrint(alloc, "count is: {any}\nchao\n", .{ct});
    defer alloc.free(result);

    try outputFile.writeAll(result);
    _ = try std.io.getStdOut().write("Completed write!\n");
}

fn loadLevel(parentAlloc: std.mem.Allocator, rawFile: []const u8) ![]u8 {
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

    const mainLayer: *ldtk.LayerInstance = forLayer: {
        if (level.layerInstances) |layers| {
            for (layers) |*l| {
                if (std.mem.eql(u8, l.__identifier, "AutoLayer")) {
                    break :forLayer l;
                }
            }
        }
        @panic("Could not find AutoLayer");
    };

    var resultArr: std.ArrayList(u8) = std.ArrayList(u8).init(parentAlloc);
    errdefer resultArr.deinit();
    const resultWriter = resultArr.writer();

    const spawnPos = extractSpawnPosition(level);
    try resultWriter.print("S {any} {any}\n", .{ spawnPos[0], spawnPos[1] });

    const wallIds = extractWallTileIDs(&root.root);

    for (mainLayer.autoLayerTiles) |tile| {
        const x = tile.px[0];
        const y = tile.px[1];
        const isWall = std.mem.indexOfScalar(i64, wallIds, tile.t) != null;
        const wallToken = if (isWall) "W" else "_";

        try resultWriter.print("{any} {any} {s} {any}\n", .{ x, y, wallToken, tile.t });
    }

    try resultWriter.print("Done!\n", .{});

    return try resultArr.toOwnedSlice();
}

fn extractSpawnPosition(level: *const ldtk.Level) [2]i64 {
    for (level.layerInstances.?) |layer| {
        for (layer.entityInstances) |entity| {
            if (!std.mem.eql(u8, entity.__identifier, "Spawn")) continue;
            return entity.px;
        }
    }
    @panic("Did not find Spawn entity");
}

fn extractWallTileIDs(root: *const ldtk.Root) []const i64 {
    for (root.defs.?.tilesets) |tileset| {
        if (!std.mem.eql(u8, tileset.identifier, "Dungeon_inv_8_8")) {
            continue;
        }

        for (tileset.enumTags) |enumTag| {
            if (!std.mem.eql(u8, enumTag.enumValueId, "Wall")) {
                continue;
            }

            return enumTag.tileIds;
        }
    }

    @panic("Did not find wall tile IDs");
}
