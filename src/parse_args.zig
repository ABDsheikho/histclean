const std = @import("std");
const mem = std.mem;

pub const Args = struct {
    help: bool = false,
    dryRun: bool = false,
    backup: bool = false,
    input_path: ?[]const u8 = null,
    output_path: ?[]const u8 = null,
};

pub fn parseArgs(args: std.process.Args, allocator: mem.Allocator) !Args {
    var list: std.ArrayList([]const u8) = .empty;
    var iter = try args.iterateAllocator(allocator);
    defer iter.deinit();
    while (iter.next()) |arg| try list.append(allocator, arg);
    return parseArgsFromSlice(list.items);
}

pub fn parseArgsFromSlice(args_slice: []const []const u8) !Args {
    var arg_struct = Args{};
    for (args_slice, 0..) |arg, i| {
        if (mem.eql(u8, arg, "-h") or mem.eql(u8, arg, "--help")) arg_struct.help = true;
        if (mem.eql(u8, arg, "-d") or mem.eql(u8, arg, "--dry-run")) arg_struct.dryRun = true;
        if (mem.eql(u8, arg, "-b") or mem.eql(u8, arg, "--backup")) arg_struct.backup = true;
        if (mem.eql(u8, arg, "-i") or mem.eql(u8, arg, "--input")) {
            if (i + 1 >= args_slice.len or mem.startsWith(u8, args_slice[i + 1], "-")) return error.MissingPath;
            arg_struct.input_path = args_slice[i + 1];
        }
        if (mem.eql(u8, arg, "-o") or mem.eql(u8, arg, "--output")) {
            if (i + 1 >= args_slice.len or mem.startsWith(u8, args_slice[i + 1], "-")) return error.MissingPath;
            arg_struct.output_path = args_slice[i + 1];
        }
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
    try std.testing.expectError(error.MissingPath, parseArgsFromSlice(&.{"-i"}));
    try std.testing.expectError(error.MissingPath, parseArgsFromSlice(&.{"-o"}));
    try std.testing.expectError(error.MissingPath, parseArgsFromSlice(&.{ "-i", "-d" }));
}

test "parseArgs: multiple flags" {
    const args = try parseArgsFromSlice(&.{ "-d", "-b", "-i", "test/history" });
    try std.testing.expectEqual(true, args.dryRun);
    try std.testing.expectEqual(true, args.backup);
    try std.testing.expectEqualStrings("test/history", args.input_path.?);
}
