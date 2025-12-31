const std = @import("std");

const base64_table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

fn get_b64_val(val: ?u8) u8 {
    if (val) |x| {
        return base64_table[x];
    } else {
        return '=';
    }
}

fn get_b64_index(val: u8) !u8 {
    for (base64_table, 0..) |c, i| {
        if (c == val) {
            return @intCast(i);
        }
    }
    return error.InvalidBase64Char;
}

pub fn encode_b64(input: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const remainder = input.len % 3;
    var output_buf_len = input.len / 3 * 4;
    if (remainder > 0) {
        output_buf_len += 4;
    }
    const output_buf = try allocator.alloc(u8, output_buf_len);
    errdefer allocator.free(output_buf);

    var i: usize = 0;
    var output_index: usize = 0;
    var c1: ?u8 = null;
    var c2: ?u8 = null;
    var c3: ?u8 = null;
    var c4: ?u8 = null;
    while (i < input.len) {
        // slice sizes
        //   - 1 byte  -> 2 chunks + padding
        //   - 2 bytes -> 3 chunks + padding
        //   - 3 bytes -> 4 chunks
        c1 = null;
        c2 = null;
        c3 = null;
        c4 = null;
        switch (input.len - i) {
            1 => {
                const view = input[i .. i + 1];
                c1 = (view[0] >> 2) & 0x3F;
                c2 = (view[0] << 6) & 0x30;
                i += 1;
            },
            2 => {
                const view = input[i .. i + 2];
                c1 = (view[0] >> 2) & 0x3F;
                c2 = ((view[0] & 0x3) << 4) | ((view[1] >> 4) & 0xF);
                c3 = (view[1] & 0xF) << 2;
                i += 2;
            },
            else => {
                const view = input[i .. i + 3];
                c1 = (view[0] >> 2) & 0x3F;
                c2 = ((view[0] & 0x3) << 4) | ((view[1] >> 4) & 0xF);
                c3 = ((view[1] & 0xF) << 2) | ((view[2] >> 6) & 0x3);
                c4 = view[2] & 0x3F;
                i += 3;
            },
        }
        output_buf[output_index] = get_b64_val(c1);
        output_index += 1;
        output_buf[output_index] = get_b64_val(c2);
        output_index += 1;
        output_buf[output_index] = get_b64_val(c3);
        output_index += 1;
        output_buf[output_index] = get_b64_val(c4);
        output_index += 1;
    }
    return output_buf;
}

pub fn decode_b64(input: []const u8, allocator: std.mem.Allocator) ![]u8 {
    if (input.len < 4 or input.len % 4 != 0) {
        std.debug.print("here {s} {}", .{input, input.len});
        return error.InvalidBase64Input;
    }

    var output_buf_len: usize = input.len / 4 * 3;
    if (std.mem.eql(u8, input[input.len - 2 ..], "==")) {
        output_buf_len -= 2;
    } else if (std.mem.eql(u8, input[input.len - 1 ..], "=")) {
        output_buf_len -= 1;
    }

    var output_buf = try allocator.alloc(u8, output_buf_len);
    errdefer allocator.free(output_buf);

    var output_index: usize = 0;
    var i: usize = 0;
    while (i < input.len) : (i += 4) {
        const c1 = input[i];
        const c2 = input[i + 1];
        const c3 = input[i + 2];
        const c4 = input[i + 3];

        if (c1 == '=' or c2 == '=') {
            return error.InvalidBase64Input;
        }
        if (c3 == '=' and c4 != '=') {
            return error.InvalidBase64Input;
        }

        // only 1 byte to add to output_buf
        if (c3 == '=' and c4 == '=') {
            const b1 = ((try get_b64_index(c1) & 0x3F) << 2) | ((try get_b64_index(c2) >> 4) & 0x3);
            output_buf[output_index] = b1;
            output_index += 1;
        }
        // only 2 bytes to add to output_buf
        else if (c4 == '=') {
            const b1 = ((try get_b64_index(c1) & 0x3F) << 2) | ((try get_b64_index(c2) >> 4) & 0x3);
            const b2 = ((try get_b64_index(c2) & 0xF) << 4) | ((try get_b64_index(c3) >> 2) & 0xF);
            output_buf[output_index] = b1;
            output_index += 1;
            output_buf[output_index] = b2;
            output_index += 1;
        }
        // all 3 bytes to add to output_buf
        else {
            const b1 = ((try get_b64_index(c1) & 0x3F) << 2) | ((try get_b64_index(c2) >> 4) & 0x3);
            const b2 = ((try get_b64_index(c2) & 0xF) << 4) | ((try get_b64_index(c3) >> 2) & 0xF);
            const b3 = ((try get_b64_index(c3) & 0x3) << 6) | try get_b64_index(c4);
            output_buf[output_index] = b1;
            output_index += 1;
            output_buf[output_index] = b2;
            output_index += 1;
            output_buf[output_index] = b3;
            output_index += 1;
        }
    }

    return output_buf;
}

test "encoder: base64 input remainder 0" {
    const gpa = std.testing.allocator;
    const b64 = try encode_b64("hey", gpa);
    defer gpa.free(b64);

    try std.testing.expectEqualSlices(u8, "aGV5", b64);
}

test "encoder: base64 input remainder 1" {
    const gpa = std.testing.allocator;
    const b64 = try encode_b64("hi", gpa);
    defer gpa.free(b64);

    try std.testing.expectEqualSlices(u8, "aGk=", b64);
}

test "encoder: base64 input remainder 2" {
    const gpa = std.testing.allocator;
    const b64 = try encode_b64("h", gpa);
    defer gpa.free(b64);

    try std.testing.expectEqualSlices(u8, "aA==", b64);
}

test "encoder: hello world" {
    const gpa = std.testing.allocator;
    const b64 = try encode_b64("Hello World!", gpa);
    defer gpa.free(b64);

    try std.testing.expectEqualSlices(u8, "SGVsbG8gV29ybGQh", b64);
}

test "decoder: single char" {
    const gpa = std.testing.allocator;
    const decoded = try decode_b64("eA==", gpa);
    defer gpa.free(decoded);

    try std.testing.expectEqualSlices(u8, "x", decoded);
}

test "decoder: 2 chars" {
    const gpa = std.testing.allocator;
    const decoded = try decode_b64("eGQ=", gpa);
    defer gpa.free(decoded);

    try std.testing.expectEqualSlices(u8, "xd", decoded);
}

test "decoder: 3 chars" {
    const gpa = std.testing.allocator;
    const decoded = try decode_b64("aGV5", gpa);
    defer gpa.free(decoded);

    try std.testing.expectEqualSlices(u8, "hey", decoded);
}

test "decoder: hello world" {
    const gpa = std.testing.allocator;
    const decoded = try decode_b64("aGVsbG8sIHdvcmxkIQ==", gpa);
    defer gpa.free(decoded);

    try std.testing.expectEqualSlices(u8, "hello, world!", decoded);
}
