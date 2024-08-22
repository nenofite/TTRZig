const std = @import("std");
const p = @import("global_playdate.zig");
const panic_handler = @import("panic_handler.zig");
const tween = @import("tween.zig");
const pat = @import("pattern.zig");
const icons = @import("icons.zig");
const sounds = @import("sounds.zig");
const images = @import("images.zig");

const Arrow = @import("Arrow.zig");
const Haze = @import("Haze.zig");
const SpriteArena = @import("SpriteArena.zig");
const Camera = @import("Camera.zig");
const Gauge = @import("Gauge.zig");
const Coin = @import("Coin.zig");
const Score = @import("Score.zig");
const LevelParser = @import("LevelParser.zig");

pub const panic = panic_handler.panic;

const TILE_SIZE = 8;

pub export fn eventHandler(pd_: *p.PlaydateAPI, event: p.PDSystemEvent, arg: u32) callconv(.C) c_int {
    _ = arg;
    switch (event) {
        .EventInit => {
            //NOTE: Initalizing the panic handler should be the first thing that is done.
            //      If a panic happens before calling this, the simulator or hardware will
            //      just crash with no message.
            panic_handler.init(pd_);
            init(pd_);

            pd_.system.setUpdateCallback(update_and_render, null);
        },
        .EventTerminate => {
            deinit();
        },
        else => {},
    }
    return 0;
}

fn init(pd_: *p.PlaydateAPI) void {
    p.init_playdate(pd_);
    images.init();
    icons.init();
    sounds.init();
    p.playdate.display.setRefreshRate(tween.framerate);
    const allocd: ?*TopState = @ptrCast(@alignCast(p.playdate.system.realloc(null, @sizeOf(TopState))));
    state = allocd.?;
    state.* = TopState.init() catch unreachable; //@panic("Could not init TopState");
    p.log("Finished setup", .{});
}

fn deinit() void {
    p.log("Tearing down", .{});
    state.deinit();
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
        self.velX *= 0.9;
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
        if (btns.current.left) {
            self.velX = -1;
        } else if (btns.current.right) {
            self.velX = 1;
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
    if (otherTag == Coin.tag) {
        return .CollisionTypeOverlap;
    } else {
        return .CollisionTypeSlide;
    }
}

const MainScreen = struct {
    arena: *SpriteArena,
    blimp: ?*p.LCDSprite = null,
    blimpState: BlimpDynamics = undefined,
    haze: *Haze = undefined,
    camera: Camera = undefined,
    ballastGauge: *Gauge = undefined,
    coins: std.ArrayList(*Coin),
    arrows: std.ArrayList(*Arrow),
    score: *Score = undefined,

    pub fn init() !*MainScreen {
        const arena = try SpriteArena.init(p.allocator);
        errdefer arena.deinit();

        const self = try arena.alloc.create(MainScreen);
        errdefer arena.alloc.destroy(self);

        self.* = .{
            .arena = arena,
            .coins = std.ArrayList(*Coin).init(arena.alloc),
            .arrows = std.ArrayList(*Arrow).init(arena.alloc),
        };
        errdefer self.deinitAllEntities();

        var spawnCoords = [2]i32{ 0, 0 };
        const level = try self.loadLevel(&spawnCoords);
        errdefer self.arena.freeSprite(level);

        const blimp = try self.arena.newSprite();
        errdefer self.arena.freeSprite(blimp);
        self.blimp = blimp;

        self.haze = try Haze.init(self.arena);
        errdefer self.haze.deinit();

        self.score = try Score.init(arena);
        errdefer self.score.deinit();

        self.ballastGauge = try Gauge.init(self.arena, .{
            .cx = 387,
            .cy = 194,
            .maxAngle = 280,
            .minAngle = 80,
            .ticks = BlimpDynamics.ticks + 1,
            .tickLength = 7,
            .radius = 37,
            .zIndex = 10,
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
        p.playdate.sprite.setZIndex(blimp, 2);
        p.playdate.sprite.moveTo(blimp, spawnX, spawnY);
        p.playdate.sprite.setCollisionResponseFunction(blimp, blimpCollisionResponse);
        p.playdate.sprite.addSprite(blimp);
        self.blimpState = .{ .x = spawnX, .y = spawnY };

        self.camera = Camera.resetAt(self.blimpState.x, self.blimpState.y);

        p.playdate.graphics.setBackgroundColor(.ColorBlack);

        return self;
    }

    pub fn update(self: *MainScreen) !void {
        const blimp = self.blimp.?;
        self.blimpState.update();

        // self.score.score +%= 1;
        // if (self.score.score > 999) self.score.score = 0;
        self.score.update();

        const collisionsOpt = p.moveWithCollisions(blimp, &self.blimpState.x, &self.blimpState.y);
        if (collisionsOpt) |collisions| {
            // defer p.allocator.free(collisions);
            defer _ = p.playdate.system.realloc(collisions.ptr, 0);

            for (collisions) |collision| {
                const otherTag = p.playdate.sprite.getTag(collision.other.?);
                if (otherTag == Coin.tag) {
                    p.log("Got a coin!", .{});
                    if (self.findCoinOfSprite(collision.other.?)) |coin| {
                        self.onHitCoin(coin);
                    }
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

    fn loadLevel(self: *MainScreen, spawnCoords: *[2]i32) !*p.LCDSprite {
        const alloc = self.arena.alloc;
        p.log("Loading file", .{});
        const rawFile = loadWholeFile(alloc, "minlevels.txt") catch @panic("Couldn't load minlevels.txt");
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

        const levelImg = p.playdate.graphics.newBitmap(dims.width, dims.height, @intFromEnum(p.LCDSolidColor.ColorBlack)) orelse @panic("Can't make level bitmap");
        errdefer p.playdate.graphics.freeBitmap(levelImg);

        const levelSprite = try self.arena.newSprite();
        errdefer self.arena.freeSprite(levelSprite);

        // Draw bitmap
        {
            p.playdate.graphics.pushContext(levelImg);
            defer p.playdate.graphics.popContext();
            defer p.log("Finished drawing level", .{});
            p.playdate.graphics.setDrawMode(.DrawModeCopy);

            p.log("Parsing file", .{});

            var tileCount: u32 = 0;
            const tileSection = parser.section('T', struct { x: i32, y: i32, wallToken: u8, id: i32 }) orelse return error.LoadLevel;
            while (tileSection.next()) |tile| {
                const isWall = tile.wallToken == 'W';
                _ = try self.addTile(tile.x, tile.y, tile.id, isWall);
                tileCount += 1;
            }
            p.log("Found {any} tiles", .{tileCount});
        }

        p.log("Making it into a sprite", .{});
        p.playdate.sprite.setImage(levelSprite, levelImg, .BitmapUnflipped);
        p.playdate.sprite.setCenter(levelSprite, 0, 0);
        p.playdate.sprite.setZIndex(levelSprite, -1);
        p.playdate.sprite.addSprite(levelSprite);

        return levelSprite;
    }

    fn addTile(self: *MainScreen, x: i32, y: i32, tileId: i32, isWall: bool) !void {
        const tileImg = p.playdate.graphics.getTableBitmap(images.dungeonTable, tileId) orelse return error.UnknownTile;
        if (isWall) {
            _ = try self.addEmptyCollisionSprite(.{
                .x = @floatFromInt(x),
                .y = @floatFromInt(y),
                .width = TILE_SIZE,
                .height = TILE_SIZE,
            });
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

    fn addEmptyCollisionSprite(self: *MainScreen, rect: p.PDRect) !*p.LCDSprite {
        const sprite = try self.arena.newSprite();
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

    fn onHitCoin(self: *MainScreen, coin: *Coin) void {
        sounds.playOnce(sounds.coin);
        self.removeCoin(coin);
        self.score.score +|= 1;
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
};

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

const TopState = union(enum) {
    main: *MainScreen,

    pub fn init() !TopState {
        return .{ .main = try MainScreen.init() };
    }

    pub fn deinit(self: *TopState) void {
        switch (self.*) {
            .main => |main| main.deinit(),
        }
    }

    pub fn update(self: *TopState) !void {
        switch (self.*) {
            .main => |main| try main.update(),
        }
    }
};

var state: *TopState = undefined;

fn update_and_render(userdata: ?*anyopaque) callconv(.C) c_int {
    _ = userdata;
    state.update() catch |err| {
        var buf = [1]u8{0} ** 1024;
        const result = std.fmt.bufPrintZ(&buf, "Failed update: {any}", .{err}) catch "oop";
        p.softFail(result);
    };
    p.playdate.sprite.updateAndDrawSprites();

    // returning 1 signals to the OS to draw the frame.
    return 1;
}
