const std = @import("std");
const Io = std.Io;
const mem = std.mem;
const testing = std.testing;

pub const version = "0.2.1";

const _parse_args = @import("./parse_args.zig");
pub const Args = _parse_args.Args;
pub const parseArgs = _parse_args.parseArgs;
pub const parseArgsFromSlice = _parse_args.parseArgsFromSlice;

pub const err = @import("./err.zig");

pub const ShellEnum = enum {
    bash,
    zsh,
    // fish,
};

pub const shellEnum_mapper = std.StaticStringMap(ShellEnum).initComptime(.{
    .{ "bash", .bash },
    .{ "zsh", .zsh },
    // .{ "fish", .fish },
});

pub fn getShell(env: *std.process.Environ.Map) !ShellEnum {
    if (env.get("SHELL")) |path| {
        const s = std.Io.Dir.path.basename(path);
        if (shellEnum_mapper.get(s)) |val| {
            return val;
        } else {
            return err.Errors.UnsupportedShellError;
        }
    } else {
        return err.Errors.UnsupportedShellError;
    }
}

pub fn filterLines(shell: ShellEnum, content: []const u8, allocator: mem.Allocator) ![]const []const u8 {
    switch (shell) {
        .bash => return try filterBash(content, allocator),
        .zsh => return try filterZsh(content, allocator),
    }
}

fn filterBash(content: []const u8, allocator: mem.Allocator) ![]const []const u8 {
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
    }
    std.mem.reverse([]const u8, lines.items);
    return lines.toOwnedSlice(allocator);
}

fn filterZsh(content: []const u8, allocator: mem.Allocator) ![]const []const u8 {
    // define lines as array of strings
    var lines: std.ArrayList([]const u8) = .empty;

    // Read content from end to start
    var backward_lines = mem.splitBackwardsAny(u8, content, "\n\r");

    // define a set to keep record of unique lines
    var hash_set: std.StringHashMap(void) = .init(allocator);
    defer hash_set.deinit();

    while (backward_lines.next()) |line| {
        const clean_line = mem.trim(u8, line, " \t");

        // try to parse zsh command template <: start:elapsed;command>
        var tokern_iter = mem.tokenizeAny(u8, clean_line, ":;");
        _ = tokern_iter.next();
        const zsh_identifier = tokern_iter.next();
        const cmd = tokern_iter.next() orelse clean_line;

        if (zsh_identifier) |_| {
            // check if the _second_ identifier exists
            // if it exists and cmd is equal to clean_line ->
            // then cmd was empty in the first place -> continue
            if (mem.eql(u8, cmd, clean_line)) continue;
        }

        if (hash_set.contains(cmd)) continue;

        try hash_set.put(cmd, {});
        try lines.append(allocator, clean_line);
    }
    std.mem.reverse([]const u8, lines.items);
    return lines.toOwnedSlice(allocator);
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

fn testFilterLines(shell: ShellEnum, input: []const u8, expected: []const []const u8) !void {
    const result = try filterLines(shell, input, testing.allocator);
    defer testing.allocator.free(result);
    try testing.expectEqual(expected.len, result.len);
    for (expected, result) |e, a| try testing.expectEqualStrings(e, a);
}

test "filterLines: basic dedup removes duplicates" {
    inline for (std.meta.tags(ShellEnum)) |shell| {
        const input = switch (shell) {
            .bash =>
            \\#123
            \\echo hi
            \\#456
            \\echo hi
            \\#789
            \\echo bye
            ,
            .zsh =>
            \\: 100:0;echo first
            \\: 200:0;echo second
            \\: 300:0;echo first
            ,
        };
        const expected = switch (shell) {
            .bash => &[_][]const u8{ "#456", "echo hi", "#789", "echo bye" },
            .zsh => &[_][]const u8{ ": 200:0;echo second", ": 300:0;echo first" },
        };
        try testFilterLines(shell, input, expected);
    }
}

test "filterLines(bash): consecutive timestamps dedup to one" {
    const input =
        \\#123
        \\echo hi
        \\#45
        \\#789
        \\echo bye
    ;
    const expected = &[_][]const u8{ "#123", "echo hi", "#789", "echo bye" };
    try testFilterLines(.bash, input, expected);
}

test "filterLines: single line" {
    inline for (std.meta.tags(ShellEnum)) |shell| {
        try testFilterLines(shell, "echo hi", &.{"echo hi"});
    }
}

test "filterLines: all duplicates" {
    const input =
        \\echo hi
        \\echo hi
        \\echo hi
    ;
    inline for (std.meta.tags(ShellEnum)) |shell| {
        try testFilterLines(shell, input, &.{"echo hi"});
    }
}

test "filterLines: lines with trailing spaces are trimmed" {
    const input =
        \\echo hi  
        \\echo hi
    ;
    inline for (std.meta.tags(ShellEnum)) |shell| {
        try testFilterLines(shell, input, &.{"echo hi"});
    }
}

test "filterLines: empty input returns one empty line" {
    inline for (std.meta.tags(ShellEnum)) |shell| {
        try testFilterLines(shell, "", &.{""});
    }
}

test "filterLines: no duplicates preserves all lines" {
    const input =
        \\echo first
        \\echo second
        \\echo third
    ;
    const expected = &[_][]const u8{ "echo first", "echo second", "echo third" };
    inline for (std.meta.tags(ShellEnum)) |shell| {
        try testFilterLines(shell, input, expected);
    }
}

test "filterLines(bash): only timestamps dedup to last timestamp" {
    const input =
        \\#123
        \\#456
        \\#789
    ;
    try testFilterLines(.bash, input, &.{"#789"});
}

test "filterLines: Windows-style CRLF line endings" {
    const input = "echo first\r\necho second\r\necho first\r\n";
    const expected = &[_][]const u8{ "echo second", "echo first", "" };
    inline for (std.meta.tags(ShellEnum)) |shell| {
        try testFilterLines(shell, input, expected);
    }
}

test "filterLines + writeLines: roundtrip via temp file" {
    inline for (std.meta.tags(ShellEnum)) |shell| {
        const input = switch (shell) {
            .bash =>
            \\#123
            \\echo hi
            \\#456
            \\echo hi
            \\#789
            \\echo bye
            ,
            .zsh =>
            \\: 100:0;echo first
            \\: 200:0;echo second
            \\: 300:0;echo first
            ,
        };
        const expected_str = switch (shell) {
            .bash => "#456\necho hi\n#789\necho bye",
            .zsh => ": 200:0;echo second\n: 300:0;echo first",
        };

        const result = try filterLines(shell, input, testing.allocator);
        defer testing.allocator.free(result);

        const dir = Io.Dir.cwd();
        const tmp_path = "test-histclean-tmp.out";
        const tmp_file = try Io.Dir.createFile(dir, testing.io, tmp_path, .{});
        defer {
            tmp_file.close(testing.io);
            Io.Dir.deleteFile(dir, testing.io, tmp_path) catch {};
        }

        var tmp_writer = tmp_file.writer(testing.io, &.{});
        try writeLines(&tmp_writer.interface, result);

        const verify_file = try Io.Dir.openFile(dir, testing.io, tmp_path, .{ .mode = .read_only });
        defer verify_file.close(testing.io);
        const stat = try verify_file.stat(testing.io);
        const buf = try testing.allocator.alloc(u8, stat.size);
        defer testing.allocator.free(buf);
        _ = try verify_file.readPositionalAll(testing.io, buf, 0);

        try testing.expectEqualStrings(expected_str, buf);
    }
}
