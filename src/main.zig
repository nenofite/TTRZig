const std = @import("std");
const p = @import("global_playdate.zig");
const panic_handler = @import("panic_handler.zig");
const tween = @import("tween.zig");
const pat = @import("pattern.zig");
const icons = @import("icons.zig");
const sounds = @import("sounds.zig");
const images = @import("images.zig");
const ldtk = @import("LDtk.zig");

const SpriteArena = @import("sprite_arena.zig").SpriteArena;

pub const panic = panic_handler.panic;

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
    state.* = TopState.init() catch @panic("Could not init TopState");
    p.playdate.system.logToConsole("Finished setup");
}

fn deinit() void {
    p.playdate.system.logToConsole("Tearing down");
    state.deinit();
}

const MainScreen = struct {
    arena: SpriteArena,
    blimp: ?*p.LCDSprite = null,

    pub fn init() !MainScreen {
        var self = MainScreen{
            .arena = try SpriteArena.init(p.allocator),
        };
        errdefer self.arena.deinit();
        try self.start();
        return self;
    }

    pub fn start(self: *MainScreen) !void {
        const sprite = try self.arena.newSprite();
        self.blimp = sprite;

        const image = p.playdate.graphics.getTableBitmap(images.spritesTable, 0) orelse @panic("Couldn't get sprites@0");
        p.playdate.sprite.setImage(sprite, image, .BitmapUnflipped);
        p.playdate.sprite.moveTo(sprite, 20, 20);
        p.playdate.sprite.addSprite(sprite);

        self.loadLevel();
    }

    pub fn update(self: *MainScreen) !void {
        const foo = self.blimp orelse return error.NotInit;
        p.playdate.sprite.moveBy(foo, 3, 0);
    }

    pub fn deinit(self: *MainScreen) void {
        self.arena.deinit();
    }

    fn loadLevel(self: *MainScreen) void {
        var arena = std.heap.ArenaAllocator.init(self.arena.alloc);
        defer arena.deinit();

        const alloc = arena.allocator();
        p.log("Loading file", .{});
        p.log("Arena size: {any}", .{arena.queryCapacity()});
        const rawFile = loadWholeFile(alloc, "levels.ldtk") catch @panic("Couldn't load levels.ldtk");
        defer alloc.free(rawFile);
        p.log("Parsing file", .{});
        p.log("Arena size: {any}", .{arena.queryCapacity()});
        var root = ldtk.parse(alloc, rawFile) catch @panic("Couldn't parse levels.ldtk");
        defer root.deinit();

        p.log("Iterating level", .{});
        p.log("Arena size: {any}", .{arena.queryCapacity()});
        const level: *ldtk.Level = forLevel: for (root.root.levels) |*l| {
            if (std.mem.eql(u8, l.identifier, "Level_0")) {
                break :forLevel l;
            }
        } else {
            @panic("Could not find Level_0");
        };
        if (level.layerInstances) |layers| {
            for (layers) |layer| {
                p.log("layer: {s}", .{layer.__identifier});
            }
        }
    }
};

fn loadWholeFile(alloc: std.mem.Allocator, path: [*c]const u8) ![]u8 {
    const file = p.playdate.file.open(path, p.FILE_READ) orelse return error.FileNotFound;
    defer _ = p.playdate.file.close(file);
    const buf = try alloc.alloc(u8, 1024 * 1024);
    errdefer alloc.free(buf);
    const actualLen = p.playdate.file.read(file, buf.ptr, @intCast(buf.len));
    if (actualLen <= 0) return error.FileEmpty;
    return buf[0..@intCast(actualLen)];
}

const TopState = union(enum) {
    main: MainScreen,

    pub fn init() !TopState {
        return .{ .main = try MainScreen.init() };
    }

    pub fn deinit(self: *TopState) void {
        switch (self.*) {
            .main => |*main| main.deinit(),
        }
    }

    pub fn update(self: *TopState) !void {
        switch (self.*) {
            .main => |*main| try main.update(),
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
