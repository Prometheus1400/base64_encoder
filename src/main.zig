const std = @import("std");
const encoder = @import("encoder");

fn print_correct_usage_and_exit() noreturn {
    std.debug.print("Correct flags are -d, -e for decoding and encoding\n", .{});
    std.process.exit(1);
}

const Mode = enum {
    Encoding,
    Decoding,

    pub fn from_flag(mode: []const u8) !Mode {
        if (std.mem.eql(u8, mode, "-d")) {
            return Mode.Decoding;
        }
        if (std.mem.eql(u8, mode, "-e")) {
            return Mode.Encoding;
        }
        return error.BadUsage;
    }
};

pub fn run() ![]u8 {
    var it = std.process.args();
    _ = it.next();
    const mode_flag = it.next() orelse {
        return error.BadUsage;
    };
    const mode = try Mode.from_flag(mode_flag);
    const gpa = std.heap.page_allocator;
    var input = try std.fs.File.stdin().readToEndAlloc(gpa, 1024 * 1024);
    defer gpa.free(input);

    if (input.len > 0 and input[input.len - 1] == '\n') {
        input = input[0 .. input.len-1];
    }

    switch (mode) {
        Mode.Encoding => {
            return encoder.encode_b64(input, gpa);
        },
        Mode.Decoding => {
            return encoder.decode_b64(input, gpa);
        },
    }
}

pub fn main() !void {
    const output = run() catch |err| switch (err) {
        error.BadUsage => {
            print_correct_usage_and_exit();
        },
        else => {
            std.log.debug("unknown error: {}", .{err});
            std.process.exit(1);
        },
    };
    std.debug.print("{s}\n", .{output});
}
