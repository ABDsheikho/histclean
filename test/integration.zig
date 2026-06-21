const std = @import("std");
const Io = std.Io;
const mem = std.mem;
const testing = std.testing;

const bin_path = "./zig-out/bin/histclean";
const io = testing.io;

fn runBin(argv: []const []const u8) !struct { stdout: []u8, stderr: []u8, term: std.process.Child.Term } {
    const allocator = testing.allocator;

    var child = try std.process.spawn(io, .{
        .argv = argv,
        .stdout = .pipe,
        .stderr = .pipe,
    });

    var buf1: [4096]u8 = undefined;
    var buf2: [4096]u8 = undefined;

    const stdout = stdout: {
        var file_reader = child.stdout.?.reader(io, &buf1);
        var io_reader = &file_reader.interface;
        break :stdout try io_reader.allocRemaining(allocator, .unlimited);
    };

    const stderr = stderr: {
        var file_reader = child.stderr.?.reader(io, &buf2);
        var io_reader = &file_reader.interface;
        break :stderr try io_reader.allocRemaining(allocator, .unlimited);
    };

    const term = try child.wait(io);
    return .{
        .stdout = stdout,
        .stderr = stderr,
        .term = term,
    };
}

test "output-to-file matches expected" {
    const out_path = "test/history.out";
    defer Io.Dir.deleteFile(Io.Dir.cwd(), io, out_path) catch {};

    const result = try runBin(&.{ bin_path, "-i", "test/history", "-o", out_path });
    defer testing.allocator.free(result.stdout);
    defer testing.allocator.free(result.stderr);

    try testing.expectEqual(@as(u32, 0), result.term.exited);

    const expected = try readFile("test/history.expected");
    defer testing.allocator.free(expected);

    const actual = try readFile(out_path);
    defer testing.allocator.free(actual);

    try testing.expectEqualStrings(expected, actual);
}

test "dry-run prints to stdout" {
    const result = try runBin(&.{ bin_path, "-d", "-i", "test/history" });
    defer testing.allocator.free(result.stdout);
    defer testing.allocator.free(result.stderr);

    try testing.expectEqual(@as(u32, 0), result.term.exited);

    const expected = try readFile("test/history.expected");
    defer testing.allocator.free(expected);

    try testing.expectEqualStrings(expected, result.stdout);
}

test "backup creates .backup file" {
    const tmp_path = "test/history-tmp";
    const tmp_path_backup = "test/history-tmp.backup";
    defer Io.Dir.deleteFile(Io.Dir.cwd(), io, tmp_path_backup) catch {};

    try Io.Dir.copyFile(Io.Dir.cwd(), "test/history", Io.Dir.cwd(), tmp_path, io, .{});
    defer Io.Dir.deleteFile(Io.Dir.cwd(), io, tmp_path) catch {};

    const result = try runBin(&.{ bin_path, "-b", "-i", tmp_path, "-o", tmp_path });
    defer testing.allocator.free(result.stdout);
    defer testing.allocator.free(result.stderr);

    try testing.expectEqual(@as(u32, 0), result.term.exited);

    const original = try readFile("test/history");
    defer testing.allocator.free(original);

    const backup = try readFile(tmp_path_backup);
    defer testing.allocator.free(backup);

    try testing.expectEqualStrings(original, backup);
}

test "in-place modification" {
    const tmp_path = "test/history-tmp";
    defer Io.Dir.deleteFile(Io.Dir.cwd(), io, tmp_path) catch {};

    try Io.Dir.copyFile(Io.Dir.cwd(), "test/history", Io.Dir.cwd(), tmp_path, io, .{});

    const result = try runBin(&.{ bin_path, "-i", tmp_path });
    defer testing.allocator.free(result.stdout);
    defer testing.allocator.free(result.stderr);

    try testing.expectEqual(@as(u32, 0), result.term.exited);

    const expected = try readFile("test/history.expected");
    defer testing.allocator.free(expected);

    const actual = try readFile(tmp_path);
    defer testing.allocator.free(actual);

    try testing.expectEqualStrings(expected, actual);
}

fn readFile(path: []const u8) ![]u8 {
    const file = try Io.Dir.openFile(Io.Dir.cwd(), io, path, .{ .mode = .read_only });
    defer file.close(io);
    const stat = try file.stat(io);
    const buf = try testing.allocator.alloc(u8, stat.size);
    _ = try file.readPositionalAll(io, buf, 0);
    return buf;
}
