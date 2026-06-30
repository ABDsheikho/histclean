const std = @import("std");
const mem = std.mem;
const testing = std.testing;

const err = @import("./err.zig");

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
