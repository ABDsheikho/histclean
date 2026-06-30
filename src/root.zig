const std = @import("std");
const Io = std.Io;
const mem = std.mem;
const testing = std.testing;

pub const version = "0.2.1";

const _parse_args = @import("./parse_args.zig");
pub const Args = _parse_args.Args;
pub const parseArgs = _parse_args.parseArgs;
pub const parseArgsFromSlice = _parse_args.parseArgsFromSlice;
// lazy-analysis is a thing in Zig, and it won't run test in modules that aren't used!!
comptime {
    _ = _parse_args;
}

pub const err = @import("./err.zig");

const _filter = @import("./filter.zig");
const shellEnum_mapper = _filter.shellEnum_mapper;
pub const ShellEnum = _filter.ShellEnum;
pub const filterLines = _filter.filterLines;

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
