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
    const rawFile = try inputFile.readToEndAlloc(alloc, 1024 * 1024 * 1024);
    defer alloc.free(rawFile);

    try loadLevel(alloc, rawFile, outputPath);

    _ = try std.io.getStdOut().write("Completed write!\n");
}

fn loadLevel(parentAlloc: std.mem.Allocator, rawFile: []const u8, path: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(parentAlloc);
    defer arena.deinit();
    const alloc = arena.allocator();

    var root = ldtk.parse(alloc, rawFile) catch @panic("Couldn't parse levels.ldtk");
    defer root.deinit();

    var dir = try std.fs.cwd().makeOpenPath(path, .{});
    defer dir.close();

    for (root.root.levels, 0..) |*level, num| {
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

        var filenameBuf = [1]u8{0} ** 64;
        const filename = try std.fmt.bufPrint(&filenameBuf, "L{}.txt", .{num});
        const file = try dir.createFile(filename, .{ .truncate = true });
        defer file.close();

        const resultWriter = file.writer();

        const spawnPos = extractSpawnPosition(level);
        try resultWriter.print("S {} {}\n", .{ spawnPos[0], spawnPos[1] });

        try resultWriter.print("X {} {}\n", .{ level.pxWid, level.pxHei });

        try writeEntities(alloc, "Coin", level, 'C', resultWriter);
        try writeEntities(alloc, "Arrow", level, 'A', resultWriter);
        try writeEntities(alloc, "Chest", level, 'H', resultWriter);

        const goals = try extractEntityRects(alloc, "Goal", level);
        defer alloc.free(goals);
        try resultWriter.print("G\n", .{});
        for (goals) |goal| {
            try resultWriter.print("{} {} {} {}\n", .{ goal.x, goal.y, goal.width, goal.height });
        }

        try writeEntities(alloc, "Crossbow", level, 'B', resultWriter);

        const wallIds = extractTileIDs(&root.root, "Wall");
        const skipIds = extractTileIDs(&root.root, "Skip");
        const spikeIds = extractTileIDs(&root.root, "Spike");

        const idToToken = [_]struct { ids: []const i64, token: []const u8 }{
            .{ .ids = wallIds, .token = "W" },
            .{ .ids = spikeIds, .token = "S" },
        };

        _ = try resultWriter.write("T\n");
        for (mainLayer.autoLayerTiles) |tile| {
            const x = tile.px[0];
            const y = tile.px[1];
            const shouldSkip = std.mem.indexOfScalar(i64, skipIds, tile.t) != null;
            if (shouldSkip) continue;

            const token = for (idToToken) |pair| {
                if (std.mem.indexOfScalar(i64, pair.ids, tile.t) != null) {
                    break pair.token;
                }
            } else "_";

            try resultWriter.print("{} {} {s} {}\n", .{ x, y, token, tile.t });
        }
    }
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

fn extractEntityPositions(alloc: std.mem.Allocator, name: []const u8, level: *const ldtk.Level) ![][2]i64 {
    var result = std.ArrayList([2]i64).init(alloc);
    errdefer result.deinit();

    for (level.layerInstances.?) |layer| {
        for (layer.entityInstances) |entity| {
            if (!std.mem.eql(u8, entity.__identifier, name)) continue;
            try result.append(entity.px);
        }
    }
    return try result.toOwnedSlice();
}

fn writeEntities(alloc: std.mem.Allocator, jsonName: []const u8, level: *const ldtk.Level, section: u8, writer: anytype) !void {
    const entities = try extractEntityPositions(alloc, jsonName, level);
    defer alloc.free(entities);

    try writer.print("{c}\n", .{section});
    for (entities) |entity| {
        try writer.print("{} {}\n", .{ entity[0], entity[1] });
    }
}

const Rect = struct {
    x: i64,
    y: i64,
    width: i64,
    height: i64,
};

fn extractEntityRects(alloc: std.mem.Allocator, name: []const u8, level: *const ldtk.Level) ![]Rect {
    var result = std.ArrayList(Rect).init(alloc);
    errdefer result.deinit();

    for (level.layerInstances.?) |layer| {
        for (layer.entityInstances) |entity| {
            if (!std.mem.eql(u8, entity.__identifier, name)) continue;
            try result.append(.{ .x = entity.px[0], .y = entity.px[1], .width = entity.width, .height = entity.height });
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
