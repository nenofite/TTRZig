const std = @import("std");
const pdapi = @import("playdate_api_definitions.zig");
const builtin = @import("builtin");

var global_playate: *pdapi.PlaydateAPI = undefined;
pub fn init(playdate: *pdapi.PlaydateAPI) void {
    global_playate = playdate;
}

pub fn panic(
    msg: []const u8,
    error_return_trace: ?*std.builtin.StackTrace,
    return_address: ?usize,
) noreturn {
    // _ = error_return_trace;
    _ = return_address;

    var stackBuf = [1]u8{0} ** 512;
    const stack = if (error_return_trace) |trace| miniStack(&stackBuf, trace) else "(no trace)";

    var msgFmt = [1]u8{0} ** 512;
    _ = std.fmt.bufPrintZ(msgFmt[0 .. msgFmt.len - 1], "{s}\n{s}", .{ msg, stack }) catch {};

    switch (comptime builtin.os.tag) {
        .freestanding => {
            //Playdate hardware

            //TODO: The Zig std library does not yet support stacktraces on Playdate hardware.
            //We will need to do this manually. Some notes on trying to get it working:
            //Frame pointer is R7
            //Next Frame pointer is *R7
            //Return address is *(R7+4)
            //To print out the trace corrently,
            //We need to know the load address and it doesn't seem to be exactly
            //0x6000_0000 as originally thought

            global_playate.system.@"error"("PANIC: %s\n", &msgFmt);
        },
        else => {
            // std.builtin.default_panic(msg, error_return_trace, return_address);
            while (true) global_playate.system.@"error"("PANIC: %s\n", &msgFmt);
        },
    }

    while (true) {}
}

fn miniStack(buf: []u8, stack_trace: *std.builtin.StackTrace) []const u8 {
    var stream = std.io.fixedBufferStream(buf);
    var writer = stream.writer();

    attempt: {
        if (builtin.strip_debug_info) {
            return "Unable to dump stack trace: debug info stripped\n";
        }
        const debug_info = std.debug.getSelfDebugInfo() catch |err| {
            writer.print("Unable to dump stack trace: Unable to open debug info: {s}\n", .{@errorName(err)}) catch break :attempt;
            break :attempt;
        };

        var frame_index: usize = 0;
        var frames_left: usize = @min(stack_trace.index, stack_trace.instruction_addresses.len);

        while (frames_left != 0) : ({
            frames_left -= 1;
            frame_index = (frame_index + 1) % stack_trace.instruction_addresses.len;
        }) {
            const return_address = stack_trace.instruction_addresses[frame_index];
            std.debug.printSourceAtAddress(debug_info, writer, return_address - 1, .no_color) catch break :attempt;
        }

        if (stack_trace.index > stack_trace.instruction_addresses.len) {
            const dropped_frames = stack_trace.index - stack_trace.instruction_addresses.len;
            writer.print("({d} additional stack frames skipped...)\n", .{dropped_frames}) catch break :attempt;
        }
    }

    return stream.getWritten();
}
