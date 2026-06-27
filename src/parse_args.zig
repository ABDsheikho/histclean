const std = @import("std");
const mem = std.mem;
const testing = std.testing;

const err = @import("./err.zig");

pub const Args = struct {
    help: bool = false,
    version: bool = false,
    dryRun: bool = false,
    backup: bool = false,
    input_path: ?[]const u8 = null,
    output_path: ?[]const u8 = null,
    completion: ?Completion = null,
};

pub const Completion = enum {
    bash,
    zsh,
};

const arg_to_enum_mapper = std.StaticStringMap(enum {
    help,
    version,
    dryRun,
    backup,
    input,
    output,
    completion,
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
    .{ "-c", .completion },
    .{ "--completion", .completion },
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
                .completion => {
                    i += 1;
                    if (i >= args_slice.len or mem.startsWith(u8, args_slice[i], "-")) return err.Errors.InvalidArgument;
                    const v = args_slice[i];
                    if (mem.eql(u8, v, "bash")) {
                        arg_struct.completion = .bash;
                        continue;
                    }
                    if (mem.eql(u8, v, "zsh")) {
                        arg_struct.completion = .zsh;
                        continue;
                    }
                    return err.Errors.InvalidArgument;
                },
            }
        } else return err.Errors.InvalidArgument;
    }
    return arg_struct;
}

test "parseArgs: default values" {
    const args = try parseArgsFromSlice(&.{});
    try testing.expectEqual(false, args.help);
    try testing.expectEqual(false, args.dryRun);
    try testing.expectEqual(false, args.backup);
    try testing.expectEqual(@as(?[]const u8, null), args.input_path);
    try testing.expectEqual(@as(?[]const u8, null), args.output_path);
}

test "parseArgs: help flag" {
    const args = try parseArgsFromSlice(&.{"-h"});
    try testing.expectEqual(true, args.help);
}

test "parseArgs: dry-run flags" {
    try testing.expectEqual(true, (try parseArgsFromSlice(&.{"-d"})).dryRun);
    try testing.expectEqual(true, (try parseArgsFromSlice(&.{"--dry-run"})).dryRun);
}

test "parseArgs: backup flag" {
    try testing.expectEqual(true, (try parseArgsFromSlice(&.{"-b"})).backup);
    try testing.expectEqual(true, (try parseArgsFromSlice(&.{"--backup"})).backup);
}

test "parseArgs: input and output paths" {
    const args = try parseArgsFromSlice(&.{ "-i", "test/history", "-o", "test/out" });
    try testing.expectEqualStrings("test/history", args.input_path.?);
    try testing.expectEqualStrings("test/out", args.output_path.?);
}

test "parseArgs: missing path returns error" {
    try testing.expectError(err.Errors.MissingPath, parseArgsFromSlice(&.{"-i"}));
    try testing.expectError(err.Errors.MissingPath, parseArgsFromSlice(&.{"-o"}));
    try testing.expectError(err.Errors.MissingPath, parseArgsFromSlice(&.{ "-i", "-d" }));
}

test "parseArgs: multiple flags" {
    const args = try parseArgsFromSlice(&.{ "-d", "-b", "-i", "test/history" });
    try testing.expectEqual(true, args.dryRun);
    try testing.expectEqual(true, args.backup);
    try testing.expectEqualStrings("test/history", args.input_path.?);
}

test "parseArgs: version flag" {
    try testing.expectEqual(true, (try parseArgsFromSlice(&.{"-v"})).version);
    try testing.expectEqual(true, (try parseArgsFromSlice(&.{"--version"})).version);
}

test "parseArgs: completion flag bash" {
    try testing.expect(try parseArgsFromSlice(&.{ "-c", "bash" }).completion == .bash);
    try testing.expect(try parseArgsFromSlice(&.{ "--completion", "bash" }).completion == .bash);
}

test "parseArgs: completion flag zsh" {
    try testing.expect(try parseArgsFromSlice(&.{ "-c", "zsh" }).completion == .zsh);
    try testing.expect(try parseArgsFromSlice(&.{ "--completion", "zsh" }).completion == .zsh);
}

test "parseArgs: completion missing value returns error" {
    try testing.expectError(err.Errors.InvalidArgument, parseArgsFromSlice(&.{"-c"}));
    try testing.expectError(err.Errors.InvalidArgument, parseArgsFromSlice(&.{"--completion"}));
}

test "parseArgs: completion with flag instead of value returns error" {
    try testing.expectError(err.Errors.InvalidArgument, parseArgsFromSlice(&.{ "-c", "-d" }));
}

test "parseArgs: completion with invalid shell returns error" {
    try testing.expectError(err.Errors.InvalidArgument, parseArgsFromSlice(&.{ "-c", "powershell" }));
}

test "parseArgs: invalid argument" {
    try testing.expectError(err.Errors.InvalidArgument, parseArgsFromSlice(&.{"-!x"}));
    try testing.expectError(err.Errors.InvalidArgument, parseArgsFromSlice(&.{"--x"}));
}
