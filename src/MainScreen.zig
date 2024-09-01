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
const Arrow = @import("Arrow.zig");
const Haze = @import("Haze.zig");
const Camera = @import("Camera.zig");
const Gauge = @import("Gauge.zig");
const Coin = @import("Coin.zig");
const Score = @import("Score.zig");
const LevelParser = @import("LevelParser.zig");
const WinScreen = @import("WinScreen.zig");
const CrossbowBolt = @import("CrossbowBolt.zig");
const Crossbow = @import("Crossbow.zig");

const MainScreen = @This();

arena: *SpriteArena,
levelNumber: u8,
blimp: ?*p.LCDSprite = null,
leftBlow: ?*p.LCDSprite = null,
rightBlow: ?*p.LCDSprite = null,
blimpState: BlimpDynamics = undefined,
haze: *Haze = undefined,
camera: Camera = undefined,
ballastGauge: *Gauge = undefined,
coins: std.ArrayList(*Coin),
arrows: std.ArrayList(*Arrow),
bolts: std.ArrayList(*CrossbowBolt),
crossbows: std.ArrayList(*Crossbow),
score: *Score = undefined,

const TILE_SIZE = 8;

pub const Outcome = enum {
    none,
    won,
};

pub fn init(levelNumber: u8) !*MainScreen {
    const arena = try SpriteArena.init(p.allocator);
    errdefer arena.deinit();

    const self = try arena.alloc.create(MainScreen);
    errdefer arena.alloc.destroy(self);

    self.* = .{
        .arena = arena,
        .coins = std.ArrayList(*Coin).init(arena.alloc),
        .arrows = std.ArrayList(*Arrow).init(arena.alloc),
        .bolts = std.ArrayList(*CrossbowBolt).init(arena.alloc),
        .crossbows = std.ArrayList(*Crossbow).init(arena.alloc),
        .levelNumber = levelNumber,
    };
    errdefer self.deinitAllEntities();

    var spawnCoords = [2]i32{ 0, 0 };
    const level = try self.loadLevel(levelNumber, &spawnCoords);
    errdefer self.arena.freeSprite(level);

    const blimp = try self.arena.newSprite(false);
    errdefer self.arena.freeSprite(blimp);
    self.blimp = blimp;

    const leftBlow = try self.arena.newSprite(false);
    self.leftBlow = leftBlow;
    p.setZIndex(leftBlow, .blow);
    const rightBlow = try self.arena.newSprite(false);
    self.rightBlow = rightBlow;
    p.setZIndex(rightBlow, .blow);
    self.updateBlowImages();

    self.haze = try Haze.init(self.arena);
    errdefer self.haze.deinit();

    self.score = try Score.init(arena, .score);
    errdefer self.score.deinit();

    self.ballastGauge = try Gauge.init(self.arena, .{
        .cx = 387,
        .cy = 194,
        .maxAngle = 280,
        .minAngle = 80,
        .ticks = BlimpDynamics.ticks + 1,
        .tickLength = 7,
        .radius = 37,
        .z = .ballastGauge,
        .heavyTicks = .{ .min = true, .mid = true, .max = true },
    });
    errdefer self.ballastGauge.deinit();

    const spawnX: f32 = @floatFromInt(spawnCoords[0]);
    const spawnY: f32 = @floatFromInt(spawnCoords[1]);

    const image = p.playdate.graphics.getTableBitmap(images.spritesTable, 0) orelse @panic("Couldn't get sprites@0");
    p.playdate.sprite.setImage(blimp, image, .BitmapUnflipped);
    p.playdate.sprite.setCollideRect(blimp, .{
        .x = 7,
        .y = 8,
        .width = 19,
        .height = 18,
    });
    p.setZIndex(blimp, .blimp);
    p.playdate.sprite.moveTo(blimp, spawnX, spawnY);
    p.playdate.sprite.setCollisionResponseFunction(blimp, blimpCollisionResponse);
    p.playdate.sprite.addSprite(blimp);
    self.blimpState = .{ .x = spawnX, .y = spawnY };

    self.camera = Camera.resetAt(self.blimpState.x, self.blimpState.y);

    p.playdate.graphics.setBackgroundColor(.ColorBlack);

    return self;
}

fn logHex(items: anytype) void {
    var output = std.ArrayList(u8).init(p.allocator);
    defer output.deinit();
    const writer = output.writer();
    printHexSlice(items, writer) catch unreachable;
    p.log("Hex: {s}", .{output.items});
}

fn printHex(bytes: []const u8, writer: anytype) !void {
    for (bytes) |byte| {
        try writer.print("{x:0>2} ", .{byte});
    }
}

fn printHexFields(item: anytype, writer: anytype) !void {
    inline for (@typeInfo(@TypeOf(item)).Struct.fields) |field| {
        try writer.print(".{s}{{ ", .{field.name});
        switch (@typeInfo(field.type)) {
            .Struct => {
                try printHexFields(@field(item, field.name), writer);
            },
            else => {
                const bytes: []const u8 = std.mem.asBytes(&@field(item, field.name));
                try printHex(bytes, writer);
            },
        }
        try writer.print("}} ", .{});
    }
}

fn printHexSlice(items: anytype, writer: anytype) !void {
    for (items, 0..) |item, i| {
        try writer.print("[{}]{{ ", .{i});
        try printHexFields(item, writer);
        try writer.print("}} ", .{});
    }
}

pub fn update(self: *MainScreen) Outcome {
    const blimp = self.blimp.?;
    self.blimpState.update();
    self.score.update();

    sounds.thruster.setPlaying(self.blimpState.leftThrusterOn or self.blimpState.rightThrusterOn);

    var outcome = Outcome.none;

    const collisionsOpt = p.moveWithCollisions(blimp, &self.blimpState.x, &self.blimpState.y);
    if (collisionsOpt) |collisions| {
        defer _ = p.playdate.system.realloc(collisions.ptr, 0);

        // logHex(collisions);

        // p.log("Colls: {}", .{collisions.len});
        // for (collisions, 0..) |collision, i| {
        //     p.log("Coll #{}: {any}", .{ i, collision });
        // }

        var coinsToFree = std.ArrayList(*Coin).init(self.arena.alloc);
        defer coinsToFree.deinit();

        for (collisions) |collision| {
            const otherTag = p.playdate.sprite.getTag(collision.other.?);
            switch (otherTag) {
                tags.coin => {
                    p.log("Got a coin!", .{});
                    if (self.findCoinOfSprite(collision.other.?)) |coin| {
                        self.onHitCoin(coin);
                        coinsToFree.append(coin) catch unreachable;
                    }
                },
                tags.goal => {
                    p.log("Goal!", .{});
                    outcome = .won;
                },
                tags.spike => {
                    p.log("Ouch!", .{});
                    self.score.score = 0;

                    self.blimpState.velX += @as(f32, @floatFromInt(collision.normal.x)) * 3;
                    self.blimpState.velY += @as(f32, @floatFromInt(collision.normal.y)) * 3;
                },
                else => {
                    // Wall
                    var newVelX = self.blimpState.velX;
                    var newVelY = self.blimpState.velY;
                    if (collision.normal.x > 0 and newVelX < 0) newVelX *= -1;
                    if (collision.normal.x < 0 and newVelX > 0) newVelX *= -1;
                    if (collision.normal.y > 0 and newVelY < 0) newVelY *= -1;
                    // Bottom is not bouncy
                    // if (collision.normal.y < 0 and newVelY > 0) newVelY *= -1;
                    self.blimpState.velX = newVelX;
                    self.blimpState.velY = newVelY;
                },
            }
        }

        for (coinsToFree.items) |coin| {
            self.removeCoin(coin);
        }
    }
    self.camera.update(self.blimpState.x, self.blimpState.y);

    if (p.getButtonState().pushed.a) {
        const bolt = CrossbowBolt.init(self.arena, self.blimpState.x, self.blimpState.y) catch unreachable;
        self.bolts.append(bolt) catch unreachable;
    }

    self.updateBlowImages();
    const blowXOffset = 20;
    const blowYOffset = 9;
    if (self.leftBlow) |leftBlow| {
        p.playdate.sprite.moveTo(leftBlow, self.blimpState.x - blowXOffset, self.blimpState.y + blowYOffset);
        p.playdate.sprite.setVisible(leftBlow, @intFromBool(self.blimpState.leftThrusterOn));
    }
    if (self.rightBlow) |rightBlow| {
        p.playdate.sprite.moveTo(rightBlow, self.blimpState.x + blowXOffset, self.blimpState.y + blowYOffset);
        p.playdate.sprite.setVisible(rightBlow, @intFromBool(self.blimpState.rightThrusterOn));
    }

    self.ballastGauge.setFraction(self.blimpState.fraction());
    self.ballastGauge.update();

    for (self.coins.items) |coin| {
        coin.update();
    }

    for (self.arrows.items) |arrow| {
        arrow.update();
    }

    for (self.crossbows.items) |crossbow| {
        switch (crossbow.update()) {
            .none => {},
            .shoot => {
                var x: f32 = 0;
                var y: f32 = 0;
                p.playdate.sprite.getPosition(crossbow.sprite, &x, &y);
                self.addCrossbowBolt(x, y) catch unreachable;
            },
        }
    }

    for (self.bolts.items) |bolt| {
        bolt.update();
    }

    const offset = self.camera.setGraphicsOffset();
    self.haze.update(.{
        @as(i32, @intFromFloat(self.blimpState.x)) + offset[0],
        @as(i32, @intFromFloat(self.blimpState.y)) + offset[1],
    });

    return outcome;
}

pub fn deinit(self: *MainScreen) void {
    const arena = self.arena;
    self.haze.deinit();
    self.ballastGauge.deinit();
    self.score.deinit();
    self.deinitAllEntities();
    arena.alloc.destroy(self);
    arena.deinit();
}

fn deinitAllEntities(self: *MainScreen) void {
    for (self.coins.items) |coin| {
        coin.deinit();
    }
    self.coins.clearAndFree();

    for (self.arrows.items) |arrow| {
        arrow.deinit();
    }
    self.arrows.clearAndFree();

    for (self.bolts.items) |bolt| {
        bolt.deinit();
    }
    self.bolts.clearAndFree();

    for (self.crossbows.items) |crossbow| {
        crossbow.deinit();
    }
    self.crossbows.clearAndFree();
}

fn updateBlowImages(self: *MainScreen) void {
    const mspf = 1000 / 10;
    const phases = 3;
    const phase = (p.playdate.system.getCurrentTimeMilliseconds() / mspf) % phases;
    const img = p.playdate.graphics.getTableBitmap(images.blowTable, @intCast(phase)) orelse return;
    if (self.leftBlow) |leftBlow| {
        p.playdate.sprite.setImage(leftBlow, img, .BitmapUnflipped);
    }
    if (self.rightBlow) |rightBlow| {
        p.playdate.sprite.setImage(rightBlow, img, .BitmapFlippedX);
    }
}

fn loadLevel(self: *MainScreen, num: u8, spawnCoords: *[2]i32) !*p.LCDSprite {
    const alloc = self.arena.alloc;

    var filenameBuf = [1]u8{0} ** 32;
    const filename = try std.fmt.bufPrintZ(&filenameBuf, "levels/L{}.txt", .{num});

    p.log("Loading file {s}", .{filename});
    const rawFile = try loadWholeFile(alloc, filename);
    defer alloc.free(rawFile);
    p.log("File size: {any}", .{rawFile.len});

    var parser = LevelParser.init(rawFile);
    defer parser.deinit();

    const Coord = struct { x: i32, y: i32 };
    const Rect = struct { x: i32, y: i32, width: i32, height: i32 };

    const spawnSection = parser.section('S', Coord) orelse return error.LoadLevel;
    const spawn = spawnSection.next() orelse return error.LoadLevel;

    spawnCoords.* = .{ spawn.x, spawn.y };

    // Level dimensions
    const dimSection = parser.section('X', struct { width: i32, height: i32 }) orelse return error.LoadLevel;
    const dims = dimSection.next() orelse return error.LoadLevel;

    if (dims.width <= 0 or dims.height <= 0) {
        p.fmtPanic("Bad level dimensions: {any} x {any}", .{ dims.width, dims.height });
    }

    // Coins
    const coinSection = parser.section('C', Coord) orelse return error.LoadLevel;
    while (coinSection.next()) |coin| {
        _ = try self.addCoin(coin.x, coin.y);
    }

    // Arrows
    const arrowSection = parser.section('A', Coord) orelse return error.LoadLevel;
    while (arrowSection.next()) |arrow| {
        _ = try self.addArrow(arrow.x, arrow.y);
    }

    // Goals
    const goalSection = parser.section('G', Rect) orelse return error.LoadLevel;
    while (goalSection.next()) |goal| {
        _ = try self.addGoalSprite(.{
            .x = @floatFromInt(goal.x),
            .y = @floatFromInt(goal.y),
            .width = @floatFromInt(goal.width),
            .height = @floatFromInt(goal.height),
        });
    }

    // Crossbows
    const crossbowSection = parser.section('B', Coord) orelse return error.LoadLevel;
    while (crossbowSection.next()) |crossbow| {
        _ = try self.addCrossbow(@floatFromInt(crossbow.x), @floatFromInt(crossbow.y));
    }

    const levelImg = p.playdate.graphics.newBitmap(dims.width, dims.height, @intFromEnum(p.LCDSolidColor.ColorBlack)) orelse @panic("Can't make level bitmap");
    errdefer p.playdate.graphics.freeBitmap(levelImg);

    const levelSprite = try self.arena.newSprite(false);
    errdefer self.arena.freeSprite(levelSprite);

    // Draw bitmap
    {
        p.playdate.graphics.pushContext(levelImg);
        defer p.playdate.graphics.popContext();
        defer p.log("Finished drawing level", .{});
        p.playdate.graphics.setDrawMode(.DrawModeCopy);

        p.log("Parsing file", .{});

        var tileCount: u32 = 0;
        const tileSection = parser.section('T', struct { x: i32, y: i32, token: u8, id: i32 }) orelse return error.LoadLevel;
        while (tileSection.next()) |tile| {
            _ = try self.addTile(tile.x, tile.y, tile.id, tile.token);
            tileCount += 1;
        }
        p.log("Found {any} tiles", .{tileCount});
    }

    p.log("Making it into a sprite", .{});
    p.playdate.sprite.setImage(levelSprite, levelImg, .BitmapUnflipped);
    p.playdate.sprite.setCenter(levelSprite, 0, 0);
    p.setZIndex(levelSprite, .tiles);
    p.playdate.sprite.addSprite(levelSprite);

    return levelSprite;
}

fn addTile(self: *MainScreen, x: i32, y: i32, tileId: i32, token: u8) !void {
    const tileImg = p.playdate.graphics.getTableBitmap(images.dungeonTable, tileId) orelse return error.UnknownTile;
    switch (token) {
        'W' => {
            _ = try self.addWallCollider(.{
                .x = @floatFromInt(x),
                .y = @floatFromInt(y),
                .width = TILE_SIZE,
                .height = TILE_SIZE,
            });
        },
        'S' => {
            _ = try self.addSpikeCollider(.{
                .x = @floatFromInt(x),
                .y = @floatFromInt(y),
                .width = TILE_SIZE,
                .height = TILE_SIZE,
            });
        },
        else => {},
    }
    p.playdate.graphics.drawBitmap(tileImg, x, y, .BitmapUnflipped);
}

fn addCoin(self: *MainScreen, x: i32, y: i32) !*Coin {
    const coin = try Coin.init(self.arena, @floatFromInt(x), @floatFromInt(y));
    errdefer coin.deinit();

    try self.coins.append(coin);
    errdefer _ = self.coins.pop();

    return coin;
}

fn addCrossbow(self: *MainScreen, x: f32, y: f32) !void {
    const crossbow = try Crossbow.init(self.arena, x, y);
    errdefer crossbow.deinit();

    try self.crossbows.append(crossbow);
    errdefer _ = self.crossbows.pop();
}

fn addCrossbowBolt(self: *MainScreen, x: f32, y: f32) !void {
    const bolt = try CrossbowBolt.init(self.arena, x, y);
    errdefer bolt.deinit();

    try self.bolts.append(bolt);
    errdefer _ = self.bolts.pop();
}

fn addArrow(self: *MainScreen, x: i32, y: i32) !*Arrow {
    const arrow = try Arrow.init(self.arena, @floatFromInt(x), @floatFromInt(y));
    errdefer arrow.deinit();

    try self.arrows.append(arrow);
    errdefer _ = self.arrows.pop();

    return arrow;
}

fn addWallCollider(self: *MainScreen, rect: p.PDRect) !*p.LCDSprite {
    const sprite = try self.arena.newSprite(false);
    errdefer self.arena.freeSprite(sprite);
    const x = rect.x;
    const y = rect.y;
    const originRect = p.PDRect{
        .x = 0,
        .y = 0,
        .width = rect.width,
        .height = rect.height,
    };
    p.playdate.sprite.setCollideRect(sprite, originRect);
    p.playdate.sprite.moveTo(sprite, x, y);
    p.playdate.sprite.addSprite(sprite);
    return sprite;
}

fn addSpikeCollider(self: *MainScreen, rect: p.PDRect) !*p.LCDSprite {
    const sprite = try self.arena.newSprite(false);
    errdefer self.arena.freeSprite(sprite);
    const x = rect.x;
    const y = rect.y;
    const originRect = p.PDRect{
        .x = 0,
        .y = 0,
        .width = rect.width,
        .height = rect.height,
    };
    p.playdate.sprite.setCollideRect(sprite, originRect);
    p.playdate.sprite.moveTo(sprite, x, y);
    p.playdate.sprite.setTag(sprite, tags.spike);
    p.playdate.sprite.addSprite(sprite);
    return sprite;
}

fn addGoalSprite(self: *MainScreen, rect: p.PDRect) !*p.LCDSprite {
    const sprite = try self.arena.newSprite(false);
    errdefer self.arena.freeSprite(sprite);
    const x = rect.x;
    const y = rect.y;
    const originRect = p.PDRect{
        .x = 0,
        .y = 0,
        .width = rect.width,
        .height = rect.height,
    };
    p.playdate.sprite.setCollideRect(sprite, originRect);
    p.playdate.sprite.moveTo(sprite, x, y);
    p.playdate.sprite.setTag(sprite, tags.goal);
    p.playdate.sprite.addSprite(sprite);
    return sprite;
}

fn onHitCoin(self: *MainScreen, coin: *Coin) void {
    _ = coin;
    sounds.playOnce(sounds.coin);
    self.score.score +|= 5;
}

fn findCoinOfSprite(self: *const MainScreen, sprite: *p.LCDSprite) ?*Coin {
    for (self.coins.items) |coin| {
        if (coin.sprite == sprite) {
            return coin;
        }
    }
    return null;
}

fn removeCoin(self: *MainScreen, coin: *Coin) void {
    if (std.mem.indexOfScalar(*Coin, self.coins.items, coin)) |idx| {
        _ = self.coins.swapRemove(idx);
    } else {
        p.softFail("Coin not in list");
        return;
    }
    coin.deinit();
}

const BlimpDynamics = struct {
    const neutralBallast = 500;
    const maxBallast = 2 * neutralBallast;
    const maxXAccel = 2.0 / @as(comptime_float, @floatFromInt(tween.framerate));
    const maxYAccel = 2.0 / @as(comptime_float, @floatFromInt(tween.framerate));
    const ticks = 10;
    const tickSoundSpacing = @divExact(maxBallast, ticks);
    const crankDegsPerNeutral = 180;

    x: f32,
    y: f32,
    velX: f32 = 0,
    velY: f32 = 0,
    ballast: i32 = neutralBallast,
    t: u32 = 0,
    leftThrusterOn: bool = false,
    rightThrusterOn: bool = false,

    sinceLastTick: i32 = 0,

    pub fn update(self: *BlimpDynamics) void {
        self.t +%= 1;
        self.velX *= 0.95;
        self.velY *= 0.9;
        self.velX += (p.random.float(f32) - 0.5) * 0.0;
        self.velY += @sin(@as(f32, @floatFromInt(self.t)) / 50 * 6) * 0.01;

        const crankChange = p.playdate.system.getCrankChange();
        const ballastChange: i32 = @intFromFloat(crankChange / crankDegsPerNeutral * neutralBallast);
        self.sinceLastTick +|= ballastChange;
        while (self.sinceLastTick >= tickSoundSpacing) {
            self.sinceLastTick -|= tickSoundSpacing;
            sounds.playOnce(sounds.click3);
        }
        while (self.sinceLastTick <= -tickSoundSpacing) {
            self.sinceLastTick +|= tickSoundSpacing;
            sounds.playOnce(sounds.click3);
        }

        self.ballast = std.math.clamp(self.ballast +| ballastChange, 0, maxBallast);

        self.leftThrusterOn = false;
        self.rightThrusterOn = false;
        const btns = p.getButtonState();
        if (btns.current.left) {
            self.velX += -maxXAccel;
            self.rightThrusterOn = true;
        } else if (btns.current.right) {
            self.velX += maxXAccel;
            self.leftThrusterOn = true;
        }

        const diff = neutralBallast - self.ballast;
        const unclampedRatio = @as(f32, @floatFromInt(diff)) / @as(f32, @floatFromInt(neutralBallast));
        const ratio = std.math.clamp(unclampedRatio, -1, 1);
        self.velY += ratio * maxYAccel;

        self.x += self.velX;
        self.y += self.velY;
    }

    pub fn fraction(self: *const BlimpDynamics) f32 {
        const unclamped = @as(f32, @floatFromInt(self.ballast)) / (neutralBallast * 2);
        return std.math.clamp(unclamped, 0, 1);
    }
};

fn blimpCollisionResponse(self: ?*p.LCDSprite, otherOpt: ?*p.LCDSprite) callconv(.C) p.SpriteCollisionResponseType {
    _ = self;

    const other = otherOpt orelse return .CollisionTypeSlide;
    const otherTag = p.playdate.sprite.getTag(other);
    switch (otherTag) {
        tags.coin, tags.goal => return .CollisionTypeOverlap,
        tags.spike => return .CollisionTypeBounce,
        else => return .CollisionTypeSlide,
    }
}

fn loadWholeFile(alloc: std.mem.Allocator, path: [*c]const u8) ![]u8 {
    const file = p.playdate.file.open(path, p.FILE_READ) orelse return error.FileNotFound;
    defer _ = p.playdate.file.close(file);
    const buf = try alloc.alloc(u8, 1024 * 1024);
    errdefer alloc.free(buf);
    const actualLenRaw = p.playdate.file.read(file, buf.ptr, @intCast(buf.len));
    if (actualLenRaw <= 0) return error.FileEmpty;

    const actualLen: usize = @intCast(actualLenRaw);

    return try alloc.realloc(buf, actualLen);
}
