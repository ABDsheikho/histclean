const std = @import("std");
const mem = std.mem;
const Io = std.Io;

const _parse_args = @import("./parse_args.zig");
pub const Args = _parse_args.Args;
pub const parseArgs = _parse_args.parseArgs;
pub const parseArgsFromSlice = _parse_args.parseArgsFromSlice;

pub const err = @import("./err.zig");

pub fn filterLines(content: []const u8, allocator: mem.Allocator) !std.ArrayList([]const u8) {
    // define lines as array of strings
    var lines: std.ArrayList([]const u8) = .empty;

    // Read content from end to start
    var backward_lines = mem.splitBackwardsAny(u8, content, "\n\r");

    // define a set to keep record of unique lines
    var hash_set: std.StringHashMap(void) = .init(allocator);
    defer hash_set.deinit();

    // define a flag to prevent consecutive time-stamps (empty command)
    var time_stamp_flag = false;

    while (backward_lines.next()) |line| {
        const clean_line = mem.trim(u8, line, " \t");
        if (hash_set.contains(clean_line)) continue;

        // for consecutive time-stamps, keep the first, skip the rest
        if (mem.startsWith(u8, clean_line, "#")) {
            if (time_stamp_flag) continue else time_stamp_flag = true;
        } else time_stamp_flag = false;

        try hash_set.put(clean_line, {});
        try lines.append(allocator, clean_line);
        // try lines.insert(allocator, 0, clean_line);
    }
    std.mem.reverse([]const u8, lines.items);
    return lines;
}

pub fn writeLines(writer: *Io.Writer, lines: []const []const u8) !void {
    if (lines.len > 0) {
        // Write first line without \n newline char
        // The next lines start with \n newline char
        // This prevent getting empty line at the end of a file
        try writer.print("{s}", .{lines[0]});
        for (lines[1..]) |item| {
            try writer.print("\n{s}", .{item});
        }
    }
    try writer.flush();
}

test "filterLines: basic dedup removes duplicates" {
    const input =
        \\#123
        \\echo hi
        \\#456
        \\echo hi
        \\#789
        \\echo bye
    ;

    var result = try filterLines(input, std.testing.allocator);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), result.items.len);
    try std.testing.expectEqualStrings("#456", result.items[0]);
    try std.testing.expectEqualStrings("echo hi", result.items[1]);
    try std.testing.expectEqualStrings("#789", result.items[2]);
    try std.testing.expectEqualStrings("echo bye", result.items[3]);
}

test "filterLines: consecutive timestamps dedup to one" {
    const input =
        \\#123
        \\echo hi
        \\#45
        \\#789
        \\echo bye
    ;

    var result = try filterLines(input, std.testing.allocator);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), result.items.len);
    try std.testing.expectEqualStrings("#123", result.items[0]);
    try std.testing.expectEqualStrings("echo hi", result.items[1]);
    try std.testing.expectEqualStrings("#789", result.items[2]);
    try std.testing.expectEqualStrings("echo bye", result.items[3]);
}

test "filterLines: single line" {
    var result = try filterLines("echo hi", std.testing.allocator);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), result.items.len);
    try std.testing.expectEqualStrings("echo hi", result.items[0]);
}

test "filterLines: all duplicates" {
    const input =
        \\echo hi
        \\echo hi
        \\echo hi
    ;

    var result = try filterLines(input, std.testing.allocator);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), result.items.len);
}

test "filterLines: lines with trailing spaces are trimmed" {
    const input =
        \\echo hi  
        \\echo hi
    ;

    var result = try filterLines(input, std.testing.allocator);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), result.items.len);
}

test "filterLines + writeLines: roundtrip via temp file" {
    const input =
        \\#123
        \\echo hi
        \\#456
        \\echo hi
        \\#789
        \\echo bye
    ;

    var result = try filterLines(input, std.testing.allocator);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), result.items.len);

    const dir = Io.Dir.cwd();
    const tmp_path = "test-histclean-tmp.out";
    const tmp_file = try Io.Dir.createFile(dir, std.testing.io, tmp_path, .{});
    defer {
        tmp_file.close(std.testing.io);
        Io.Dir.deleteFile(dir, std.testing.io, tmp_path) catch {};
    }

    var tmp_writer = tmp_file.writer(std.testing.io, &.{});
    try writeLines(&tmp_writer.interface, result.items);

    // Read back and verify
    const verify_file = try Io.Dir.openFile(dir, std.testing.io, tmp_path, .{ .mode = .read_only });
    defer verify_file.close(std.testing.io);
    const stat = try verify_file.stat(std.testing.io);
    const buf = try std.testing.allocator.alloc(u8, stat.size);
    defer std.testing.allocator.free(buf);
    _ = try verify_file.readPositionalAll(std.testing.io, buf, 0);

    try std.testing.expectEqualStrings("#456\necho hi\n#789\necho bye", buf);
}
