const std = @import("std");
const mem = std.mem;

const err = @import("./err.zig");

pub const Args = struct {
    help: bool = false,
    version: bool = false,
    dryRun: bool = false,
    backup: bool = false,
    input_path: ?[]const u8 = null,
    output_path: ?[]const u8 = null,
};

const arg_to_enum_mapper = std.StaticStringMap(enum {
    help,
    version,
    dryRun,
    backup,
    input,
    output,
}).initComptime(.{
    .{ "-h", .help },
    .{ "--help", .help },
    .{ "-v", .version },
    .{ "--version", .version },
    .{ "-d", .dryRun },
    .{ "--dry-run", .dryRun },
    .{ "-b", .backup },
    .{ "--backup", .backup },
    .{ "-i", .input },
    .{ "--input", .input },
    .{ "-o", .output },
    .{ "--output", .output },
});

pub fn parseArgs(args: std.process.Args, allocator: mem.Allocator) !Args {
    var list: std.ArrayList([]const u8) = .empty;
    var iter = try args.iterateAllocator(allocator);
    defer iter.deinit();
    // skip the first argument, which is usually the name of the bin
    _ = iter.next();
    while (iter.next()) |arg| try list.append(allocator, arg);
    return parseArgsFromSlice(list.items);
}

pub fn parseArgsFromSlice(args_slice: []const []const u8) !Args {
    var arg_struct = Args{};
    var i: usize = 0;
    while (i < args_slice.len) : (i += 1) {
        if (arg_to_enum_mapper.get(args_slice[i])) |val| {
            switch (val) {
                .help => arg_struct.help = true,
                .version => arg_struct.version = true,
                .dryRun => arg_struct.dryRun = true,
                .backup => arg_struct.backup = true,
                .input => {
                    i += 1;
                    if (i >= args_slice.len or mem.startsWith(u8, args_slice[i], "-")) return err.Errors.MissingPath;
                    arg_struct.input_path = args_slice[i];
                },
                .output => {
                    i += 1;
                    if (i >= args_slice.len or mem.startsWith(u8, args_slice[i], "-")) return err.Errors.MissingPath;
                    arg_struct.output_path = args_slice[i];
                },
            }
        } else return err.Errors.InvalidArgument;
    }
    return arg_struct;
}

test "parseArgs: default values" {
    const args = try parseArgsFromSlice(&.{});
    try std.testing.expectEqual(false, args.help);
    try std.testing.expectEqual(false, args.dryRun);
    try std.testing.expectEqual(false, args.backup);
    try std.testing.expectEqual(@as(?[]const u8, null), args.input_path);
    try std.testing.expectEqual(@as(?[]const u8, null), args.output_path);
}

test "parseArgs: help flag" {
    const args = try parseArgsFromSlice(&.{"-h"});
    try std.testing.expectEqual(true, args.help);
}

test "parseArgs: dry-run flags" {
    try std.testing.expectEqual(true, (try parseArgsFromSlice(&.{"-d"})).dryRun);
    try std.testing.expectEqual(true, (try parseArgsFromSlice(&.{"--dry-run"})).dryRun);
}

test "parseArgs: backup flag" {
    try std.testing.expectEqual(true, (try parseArgsFromSlice(&.{"-b"})).backup);
    try std.testing.expectEqual(true, (try parseArgsFromSlice(&.{"--backup"})).backup);
}

test "parseArgs: input and output paths" {
    const args = try parseArgsFromSlice(&.{ "-i", "test/history", "-o", "test/out" });
    try std.testing.expectEqualStrings("test/history", args.input_path.?);
    try std.testing.expectEqualStrings("test/out", args.output_path.?);
}

test "parseArgs: missing path returns error" {
    try std.testing.expectError(err.Errors.MissingPath, parseArgsFromSlice(&.{"-i"}));
    try std.testing.expectError(err.Errors.MissingPath, parseArgsFromSlice(&.{"-o"}));
    try std.testing.expectError(err.Errors.MissingPath, parseArgsFromSlice(&.{ "-i", "-d" }));
}

test "parseArgs: multiple flags" {
    const args = try parseArgsFromSlice(&.{ "-d", "-b", "-i", "test/history" });
    try std.testing.expectEqual(true, args.dryRun);
    try std.testing.expectEqual(true, args.backup);
    try std.testing.expectEqualStrings("test/history", args.input_path.?);
}

test "parseArgs: version flag" {
    try std.testing.expectEqual(true, (try parseArgsFromSlice(&.{"-v"})).version);
    try std.testing.expectEqual(true, (try parseArgsFromSlice(&.{"--version"})).version);
}

test "parseArgs: invalid argument" {
    try std.testing.expectError(err.Errors.InvalidArgument, parseArgsFromSlice(&.{"-!x"}));
    try std.testing.expectError(err.Errors.InvalidArgument, parseArgsFromSlice(&.{"--x"}));
}
