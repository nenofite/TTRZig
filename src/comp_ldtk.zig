const std = @import("std");
const ldtk = @import("LDtk.zig");

const targetLevel = "Level_0";

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
        if (std.mem.eql(u8, l.identifier, targetLevel)) {
            break :forLevel l;
        }
    } else {
        @panic("Could not find " ++ targetLevel);
    };

    const mainLayer: *ldtk.LayerInstance = forLayer: {
        if (level.layerInstances) |layers| {
            for (layers) |*l| {
                if (l.autoLayerTiles.len > 0) {
                    break :forLayer l;
                }
            }
        }
        @panic("Could not find auto layer tiles");
    };

    var resultArr: std.ArrayList(u8) = std.ArrayList(u8).init(parentAlloc);
    errdefer resultArr.deinit();
    const resultWriter = resultArr.writer();

    const spawnPos = extractSpawnPosition(level);
    try resultWriter.print("S {any} {any}\n", .{ spawnPos[0], spawnPos[1] });

    try resultWriter.print("X {any} {any}\n", .{ level.pxWid, level.pxHei });

    const coins = try extractCoinPositions(alloc, level);
    defer alloc.free(coins);
    for (coins) |coin| {
        try resultWriter.print("C {any} {any}\n", .{ coin[0], coin[1] });
    }

    const wallIds = extractTileIDs(&root.root, "Wall");
    const skipIds = extractTileIDs(&root.root, "Skip");

    for (mainLayer.autoLayerTiles) |tile| {
        const x = tile.px[0];
        const y = tile.px[1];
        const shouldSkip = std.mem.indexOfScalar(i64, skipIds, tile.t) != null;
        if (shouldSkip) continue;

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

fn extractCoinPositions(alloc: std.mem.Allocator, level: *const ldtk.Level) ![][2]i64 {
    var result = std.ArrayList([2]i64).init(alloc);
    errdefer result.deinit();

    for (level.layerInstances.?) |layer| {
        for (layer.entityInstances) |entity| {
            if (!std.mem.eql(u8, entity.__identifier, "Coin")) continue;
            try result.append(entity.px);
        }
    }
    return try result.toOwnedSlice();
}

fn extractTileIDs(root: *const ldtk.Root, enumName: []const u8) []const i64 {
    for (root.defs.?.tilesets) |tileset| {
        if (!std.mem.eql(u8, tileset.identifier, "Dungeon")) {
            continue;
        }

        for (tileset.enumTags) |enumTag| {
            if (!std.mem.eql(u8, enumTag.enumValueId, enumName)) {
                continue;
            }

            return enumTag.tileIds;
        }
    }

    @panic("Did not find wall tile IDs");
}
