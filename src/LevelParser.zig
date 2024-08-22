const std = @import("std");

const LevelParser = @This();

iter: std.unicode.Utf8Iterator,

pub fn init(buf: []const u8) LevelParser {
    return .{
        .iter = .{
            .bytes = buf,
            .i = 0,
        },
    };
}

pub fn deinit(self: *LevelParser) void {
    _ = self;
}

pub fn section(self: *LevelParser, command: u8, comptime Line: type) ?Section(Line) {
    const startState = self.iter;
    tryParse: {
        _ = self.maybe('\n');
        if (!self.maybe(command)) break :tryParse;
        _ = self.maybe(' ');
        return Section(Line){ .parent = self };
    }
    self.iter = startState;
    return null;
}

fn Section(comptime Line: type) type {
    return struct {
        parent: *LevelParser,

        pub fn next(self: *const @This()) ?Line {
            const startState = self.parent.iter;
            _ = self.parent.maybe('\n');
            tryParse: {
                var result: Line = undefined;
                inline for (@typeInfo(Line).Struct.fields, 0..) |field, i| {
                    if (i > 0) {
                        if (!self.parent.maybe(' ')) break :tryParse;
                    }
                    switch (field.type) {
                        u8 => {
                            @field(result, field.name) = @intCast(self.parent.char() orelse break :tryParse);
                        },
                        i32 => |intType| {
                            @field(result, field.name) = self.parent.number(intType) orelse break :tryParse;
                        },
                        else => {
                            @compileError("Unsupported type " ++ field.name);
                        },
                    }
                }
                return result;
            }
            self.parent.iter = startState;
            return null;
        }
    };
}

// Returns a decimal number or null if the current character is not a
// digit
fn number(self: *LevelParser, comptime num: type) ?num {
    var r: ?num = null;

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
fn char(self: *LevelParser) ?u21 {
    if (self.iter.nextCodepoint()) |code_point| {
        return code_point;
    }
    return null;
}

fn maybe(self: *LevelParser, val: u21) bool {
    if (self.peek() == val) {
        _ = self.iter.nextCodepoint();
        return true;
    }
    return false;
}

// Returns the n-th next character or null if that's past the end
fn peek(self: *LevelParser) ?u21 {
    const original_i = self.iter.i;
    defer self.iter.i = original_i;

    return self.iter.nextCodepoint();
}
