const std = @import("std");
const p = @import("global_playdate.zig");

pub var bad_hurt: *p.SamplePlayer = undefined;
pub var good_hurt: *p.SamplePlayer = undefined;
pub var good_parry: *p.SamplePlayer = undefined;
pub var bad_parry: *p.SamplePlayer = undefined;

fn make(path: [*c]const u8) !*p.SamplePlayer {
    const sample = p.playdate.sound.sample.load(path) orelse {
        return error.Playdate;
    };
    errdefer p.playdate.sound.sample.freeSample(sample);

    const player = p.playdate.sound.sampleplayer.newPlayer() orelse {
        return error.Playdate;
    };
    errdefer p.playdate.sound.sampleplayer.freePlayer(player);

    p.playdate.sound.sampleplayer.setSample(player, sample);
    return player;
}

fn metaMake(comptime name: []const u8) *p.SamplePlayer {
    return make("sounds/" ++ name) catch @panic("Could not load " ++ name);
}

pub fn init() void {
    bad_hurt = metaMake("bad_hurt");
    good_hurt = metaMake("good_hurt");
    good_parry = metaMake("good_parry");
    bad_parry = metaMake("bad_parry");
}

pub fn playOnce(sound: *p.SamplePlayer) void {
    _ = p.playdate.sound.sampleplayer.play(sound, 1, 1.0);
}
