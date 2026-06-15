const std = @import("std");
const Io = std.Io;
const mem = std.mem;

const histclean = @import("histclean");

const Args = struct {
    help: bool = false,
    dryRun: bool = false,
    backup: bool = false,
    input_path: ?[]const u8 = null,
    output_path: ?[]const u8 = null,
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena: mem.Allocator = init.arena.allocator();

    // Accessing command line arguments:
    var args = try init.minimal.args.iterateAllocator(arena);
    defer args.deinit();

    const env = init.environ_map;

    _ = args.next(); // discard binary name
    var arg_struct = Args{};
    while (args.next()) |arg| {
        if (mem.eql(u8, arg, "-h") or mem.eql(u8, arg, "--help")) arg_struct.help = true;
        if (mem.eql(u8, arg, "-d") or mem.eql(u8, arg, "--dry-run")) arg_struct.dryRun = true;
        if (mem.eql(u8, arg, "-b") or mem.eql(u8, arg, "--backup")) arg_struct.backup = true;
        if (mem.eql(u8, arg, "-i") or mem.eql(u8, arg, "--input")) assignPath(&arg_struct.input_path, &args);
        if (mem.eql(u8, arg, "-o") or mem.eql(u8, arg, "--output")) assignPath(&arg_struct.output_path, &args);
    }

    if (arg_struct.help) return printHelp();

    const histfile_path = try getHistoryPath(arg_struct.input_path, env, arena);

    const histfile = try Io.Dir.openFile(Io.Dir.cwd(), io, histfile_path, .{ .mode = .read_write });
    errdefer histfile.close(io);

    // backup history file before proceeding
    if (arg_struct.backup and !arg_struct.dryRun) try backupFile(histfile_path, io);

    const file_stat = try histfile.stat(io);

    const content = try arena.alloc(u8, file_stat.size);
    defer arena.free(content);
    _ = try histfile.readPositionalAll(io, content, 0);

    var backward_lines = mem.splitBackwardsAny(u8, content, "\n\r");

    var hset: std.StringHashMap(void) = .init(arena);

    var new_lines: std.ArrayList([]const u8) = .empty;
    defer new_lines.deinit(arena);

    var time_stamp_flag = false;
    while (backward_lines.next()) |line| {
        const clean_line = mem.trim(u8, line, " ");
        if (hset.contains(clean_line)) continue;

        if (mem.startsWith(u8, clean_line, "#")) {
            if (time_stamp_flag) continue else time_stamp_flag = true;
        } else time_stamp_flag = false;

        try hset.put(clean_line, {});
        try new_lines.insert(arena, 0, clean_line);
    }

    const output_file = try getOutputFile(arg_struct, io, &histfile);
    defer output_file.close(io);

    var result_writer = output_file.writer(io, &.{});
    const writer = &result_writer.interface;

    _ = try writer.print("{s}", .{new_lines.items[0]});
    for (new_lines.items[1..]) |item| {
        _ = try writer.print("\n{s}", .{item});
    }

    try writer.flush();
}

fn printHelp() void {
    const msg =
        \\This is a help message
        \\new line
        \\
    ;
    std.debug.print("{s}", .{msg});
}

fn dryRun() void {
    return;
}

fn assignPath(str: *?[]const u8, args: *std.process.Args.Iterator) void {
    if (args.next()) |path| check: {
        if (mem.startsWith(u8, path, "-")) break :check;
        str.* = path;
        return;
    }
    printHelp();
    std.process.exit(1);
}

fn getHistoryPath(file_path: ?[]const u8, env: *std.process.Environ.Map, allocator: mem.Allocator) ![]const u8 {
    if (file_path) |path| {
        return path;
    }
    if (env.get("HISTFILE")) |histFile| {
        return histFile;
    }
    if (env.get("HOME")) |home| {
        return try Io.Dir.path.join(allocator, &[_][]const u8{ home, "history" });
    }
    return error.HistorFileNotFound;
}

fn getOutputFile(args: Args, io: Io, defaultFile: *const Io.File) !Io.File {
    if (args.dryRun) {
        return Io.File.stdout();
    }
    if (args.output_path) |path| {
        return try Io.Dir.createFile(Io.Dir.cwd(), io, path, .{});
    }
    try defaultFile.setLength(io, 0);
    return defaultFile.*;
}

fn backupFile(path: []const u8, io: Io) !void {
    var buffer: [Io.Dir.max_path_bytes]u8 = undefined;
    const cwd = Io.Dir.cwd();
    const dest_path = try std.fmt.bufPrint(&buffer, "{s}.backup", .{path});
    try Io.Dir.copyFile(cwd, path, cwd, dest_path, io, .{ .replace = true });
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    try std.testing.fuzz({}, testOne, .{});
}

fn testOne(context: void, smith: *std.testing.Smith) !void {
    _ = context;
    // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!

    const gpa = std.testing.allocator;
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(gpa);
    while (!smith.eos()) switch (smith.value(enum { add_data, dup_data })) {
        .add_data => {
            const slice = try list.addManyAsSlice(gpa, smith.value(u4));
            smith.bytes(slice);
        },
        .dup_data => {
            if (list.items.len == 0) continue;
            if (list.items.len > std.math.maxInt(u32)) return error.SkipZigTest;
            const len = smith.valueRangeAtMost(u32, 1, @min(32, list.items.len));
            const off = smith.valueRangeAtMost(u32, 0, @intCast(list.items.len - len));
            try list.appendSlice(gpa, list.items[off..][0..len]);
            try std.testing.expectEqualSlices(
                u8,
                list.items[off..][0..len],
                list.items[list.items.len - len ..],
            );
        },
    };
}
