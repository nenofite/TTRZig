const std = @import("std");
const p = @import("global_playdate.zig");

pub var click3: *p.SamplePlayer = undefined;
pub var coin: *p.SamplePlayer = undefined;
pub var loseCoin: *p.SamplePlayer = undefined;
pub var score: *p.SamplePlayer = undefined;
pub var thruster: ContinuousSound = undefined;

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

fn metaMake(comptime name: []const u8, volume: f32) *p.SamplePlayer {
    const player = make("sounds/" ++ name) catch @panic("Could not load " ++ name);
    p.playdate.sound.sampleplayer.setVolume(player, volume, volume);
    return player;
}

pub fn init() void {
    click3 = metaMake("click3", 0.1);
    p.playdate.sound.sampleplayer.setVolume(click3, 0.1, 0.1);

    coin = metaMake("coin", 0.7);
    loseCoin = metaMake("lose_coin", 0.3);
    score = metaMake("score", 0.3);
    thruster = .{ .player = metaMake("thruster", 0.3) };
}

pub fn playOnce(sound: *p.SamplePlayer) void {
    _ = p.playdate.sound.sampleplayer.play(sound, 1, 1.0);
}

pub fn playOnceVaried(sound: *p.SamplePlayer, maxVary: f32) void {
    const vary = (p.random.float(f32) * 2 - 1) * maxVary;
    _ = p.playdate.sound.sampleplayer.play(sound, 1, 1.0 + vary);
}

const ContinuousSound = struct {
    player: *p.SamplePlayer,
    started: bool = false,

    pub fn setPlaying(self: *ContinuousSound, play: bool) void {
        const isPlaying = p.playdate.sound.sampleplayer.isPlaying(self.player) != 0;
        if (isPlaying != play) {
            if (play and !self.started) {
                _ = p.playdate.sound.sampleplayer.play(self.player, 0, 1.0);
                self.started = true;
            } else {
                p.playdate.sound.sampleplayer.setPaused(self.player, @intFromBool(!play));
            }
        }
    }
};
