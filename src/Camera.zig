const std = @import("std");
const p = @import("global_playdate.zig");

x: f32,
y: f32,

pub fn resetAt(x: f32, y: f32) @This() {
    return .{
        .x = x,
        .y = y,
    };
}

pub fn update(self: *@This(), cx: f32, cy: f32) void {
    const f = 0.05;
    self.x = std.math.lerp(self.x, cx, f);
    self.y = std.math.lerp(self.y, cy, f);
}

pub fn offset(self: *const @This()) [2]i32 {
    return .{
        p.WIDTH / 2 - @as(i32, @intFromFloat(self.x)),
        p.HEIGHT / 2 - @as(i32, @intFromFloat(self.y)),
    };
}

pub fn setGraphicsOffset(self: *const @This()) [2]i32 {
    const o = self.offset();
    p.playdate.graphics.setDrawOffset(o[0], o[1]);
    return o;
}
