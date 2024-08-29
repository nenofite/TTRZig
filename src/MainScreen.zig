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

const MainScreen = @This();

arena: *SpriteArena,
levelNumber: u8,
blimp: ?*p.LCDSprite = null,
blimpState: BlimpDynamics = undefined,
haze: *Haze = undefined,
camera: Camera = undefined,
ballastGauge: *Gauge = undefined,
coins: std.ArrayList(*Coin),
arrows: std.ArrayList(*Arrow),
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
        .levelNumber = levelNumber,
    };
    errdefer self.deinitAllEntities();

    var spawnCoords = [2]i32{ 0, 0 };
    const level = try self.loadLevel(levelNumber, &spawnCoords);
    errdefer self.arena.freeSprite(level);

    const blimp = try self.arena.newSprite(false);
    errdefer self.arena.freeSprite(blimp);
    self.blimp = blimp;

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

pub fn update(self: *MainScreen) Outcome {
    const blimp = self.blimp.?;
    self.blimpState.update();
    self.score.update();

    var outcome = Outcome.none;

    const collisionsOpt = p.moveWithCollisions(blimp, &self.blimpState.x, &self.blimpState.y);
    if (collisionsOpt) |collisions| {
        // defer p.allocator.free(collisions);
        defer _ = p.playdate.system.realloc(collisions.ptr, 0);

        for (collisions) |collision| {
            const otherTag = p.playdate.sprite.getTag(collision.other.?);
            switch (otherTag) {
                tags.coin => {
                    p.log("Got a coin!", .{});
                    if (self.findCoinOfSprite(collision.other.?)) |coin| {
                        self.onHitCoin(coin);
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
    }
    self.camera.update(self.blimpState.x, self.blimpState.y);

    self.ballastGauge.setFraction(self.blimpState.fraction());
    self.ballastGauge.update();

    for (self.coins.items) |coin| {
        coin.update();
    }

    for (self.arrows.items) |arrow| {
        arrow.update();
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

    const spawnSection = parser.section('S', struct { x: i32, y: i32 }) orelse return error.LoadLevel;
    const spawn = spawnSection.next() orelse return error.LoadLevel;

    spawnCoords.* = .{ spawn.x, spawn.y };

    // Level dimensions
    const dimSection = parser.section('X', struct { width: i32, height: i32 }) orelse return error.LoadLevel;
    const dims = dimSection.next() orelse return error.LoadLevel;

    if (dims.width <= 0 or dims.height <= 0) {
        p.fmtPanic("Bad level dimensions: {any} x {any}", .{ dims.width, dims.height });
    }

    // Coins
    const coinSection = parser.section('C', struct { x: i32, y: i32 }) orelse return error.LoadLevel;
    while (coinSection.next()) |coin| {
        _ = try self.addCoin(coin.x, coin.y);
    }

    // Arrows
    const arrowSection = parser.section('A', struct { x: i32, y: i32 }) orelse return error.LoadLevel;
    while (arrowSection.next()) |arrow| {
        _ = try self.addArrow(arrow.x, arrow.y);
    }

    // Goals
    const goalSection = parser.section('G', struct { x: i32, y: i32, width: i32, height: i32 }) orelse return error.LoadLevel;
    while (goalSection.next()) |goal| {
        _ = try self.addGoalSprite(.{
            .x = @floatFromInt(goal.x),
            .y = @floatFromInt(goal.y),
            .width = @floatFromInt(goal.width),
            .height = @floatFromInt(goal.height),
        });
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
    sounds.playOnce(sounds.coin);
    self.removeCoin(coin);
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
    }
    coin.deinit();
}

const BlimpDynamics = struct {
    const neutralBallast = 500;
    const maxBallast = 2 * neutralBallast;
    const ticks = 10;
    const tickSoundSpacing = @divExact(maxBallast, ticks);

    x: f32,
    y: f32,
    velX: f32 = 0,
    velY: f32 = 0,
    ballast: i32 = neutralBallast,
    t: u32 = 0,

    ballastCrank: i32 = 0,

    pub fn update(self: *BlimpDynamics) void {
        self.t +%= 1;
        self.velX *= 0.95;
        self.velY *= 0.9;
        self.velX += (p.random.float(f32) - 0.5) * 0.0;
        self.velY += @sin(@as(f32, @floatFromInt(self.t)) / 50 * 6) * 0.01;

        const crankChange = p.playdate.system.getCrankChange();
        const ballastChange: i32 = @intFromFloat(crankChange / 360 * neutralBallast);
        self.ballastCrank +|= ballastChange;
        while (self.ballastCrank >= tickSoundSpacing) {
            self.ballastCrank -|= tickSoundSpacing;
            self.ballast +|= tickSoundSpacing;
            sounds.playOnce(sounds.click3);
        }
        while (self.ballastCrank <= -tickSoundSpacing) {
            self.ballastCrank +|= tickSoundSpacing;
            self.ballast -|= tickSoundSpacing;
            sounds.playOnce(sounds.click3);
        }

        self.ballast = std.math.clamp(self.ballast, 0, maxBallast);

        const btns = p.getButtonState();
        const accel = 2.0 / @as(comptime_float, @floatFromInt(tween.framerate));
        if (btns.current.left) {
            self.velX += -accel;
        } else if (btns.current.right) {
            self.velX += accel;
        }

        const diff = neutralBallast - self.ballast;
        const unclampedRatio = @as(f32, @floatFromInt(diff)) / @as(f32, @floatFromInt(neutralBallast));
        const ratio = std.math.clamp(unclampedRatio, -1, 1);
        self.velY += ratio * 0.1;

        self.x += self.velX;
        self.y += self.velY;
    }

    pub fn fraction(self: *const BlimpDynamics) f32 {
        const unclamped = @as(f32, @floatFromInt(self.ballast)) / (neutralBallast * 2);
        return std.math.clamp(unclamped, 0, 1);
    }
};

fn blimpCollisionResponse(self: ?*p.LCDSprite, other: ?*p.LCDSprite) callconv(.C) p.SpriteCollisionResponseType {
    _ = self;
    const otherTag = p.playdate.sprite.getTag(other.?);
    switch (otherTag) {
        tags.coin, tags.goal => return .CollisionTypeOverlap,
        tags.spike => return .CollisionTypeFreeze,
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
