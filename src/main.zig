const std = @import("std");
const p = @import("global_playdate.zig");
const panic_handler = @import("panic_handler.zig");
const tween = @import("tween.zig");
const pat = @import("pattern.zig");
const icons = @import("icons.zig");
const sounds = @import("sounds.zig");
const images = @import("images.zig");

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
        const rawFile = loadWholeFile(alloc, "minlevels.txt") catch @panic("Couldn't load minlevels.txt");
        defer alloc.free(rawFile);
        p.log("Parsing file", .{});
        p.log("Arena size: {any}", .{arena.queryCapacity()});

        var parser = Parser.init(rawFile);
        defer parser.deinit();
        parseLines: while (true) {
            _ = parser.maybe('\n');
            if (parser.number()) |x| {
                if (parser.maybe(' ')) {
                    if (parser.number()) |y| {
                        if (parser.maybe(' ')) {
                            if (parser.char()) |wallToken| {
                                const isWall = wallToken == 'W';
                                if (parser.maybe(' ')) {
                                    if (parser.number()) |id| {
                                        p.log("parsed: {any} {any} {any} {any}", .{ x, y, isWall, id });
                                        continue :parseLines;
                                    }
                                }
                            }
                        }
                    }
                }
            }
            break :parseLines;
        }
    }
};

pub const Parser = struct {
    iter: std.unicode.Utf8Iterator,

    pub fn init(buf: []const u8) Parser {
        return .{
            .iter = .{
                .bytes = buf,
                .i = 0,
            },
        };
    }

    pub fn deinit(self: *Parser) void {
        _ = self;
    }

    // Returns a decimal number or null if the current character is not a
    // digit
    pub fn number(self: *@This()) ?usize {
        var r: ?usize = null;

        while (self.peek()) |code_point| {
            switch (code_point) {
                '0'...'9' => {
                    if (r == null) r = 0;
                    r.? *= 10;
                    r.? += code_point - '0';
                },
                else => break,
            }
            _ = self.iter.nextCodepoint();
        }

        return r;
    }

    // Returns one character, if available
    pub fn char(self: *@This()) ?u21 {
        if (self.iter.nextCodepoint()) |code_point| {
            return code_point;
        }
        return null;
    }

    pub fn maybe(self: *@This(), val: u21) bool {
        if (self.peek() == val) {
            _ = self.iter.nextCodepoint();
            return true;
        }
        return false;
    }

    // Returns the n-th next character or null if that's past the end
    pub fn peek(self: *@This()) ?u21 {
        const original_i = self.iter.i;
        defer self.iter.i = original_i;

        return self.iter.nextCodepoint();
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
