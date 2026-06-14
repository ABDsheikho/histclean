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

    _ = args.next(); // discard binary name
    var arg_struct = Args{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) arg_struct.help = true;
        if (std.mem.eql(u8, arg, "-d") or std.mem.eql(u8, arg, "--dry-run")) arg_struct.dryRun = true;
        if (std.mem.eql(u8, arg, "-b") or std.mem.eql(u8, arg, "--backup")) arg_struct.backup = true;
        if (std.mem.eql(u8, arg, "-i") or std.mem.eql(u8, arg, "--input")) {
            const path = args.next() orelse return;
            if (std.mem.startsWith(u8, path, "-")) return;
            arg_struct.input_path = path;
        }
        if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--output")) {
            const path = args.next() orelse return;
            if (std.mem.startsWith(u8, path, "-")) return;
            arg_struct.output_path = path;
        }
    }

    if (arg_struct.help) return print_help();

    // var v : std.Io.File = .stdin();

    // const histfile = try std.Io.Dir.openFileAbsolute(io, histfile_path, .{ .mode = .read_write });
    // const histfile = try std.Io.Dir.openFile(Io.Dir.cwd(), io, "./test/history", .{ .mode = .read_write });
    const histfile = hist_scope: {
        if (arg_struct.input_path) |path| {
            if (std.fs.path.isAbsolute(path)) {
                break :hist_scope try Io.Dir.openFileAbsolute(io, path, .{ .mode = .read_write });
            } else {
                break :hist_scope try Io.Dir.openFile(Io.Dir.cwd(), io, path, .{ .mode = .read_write });
            }
        } else {
            const env = init.environ_map;
            const home_var = env.get("HOME").?;
            const histfile_path: []const u8 = if (env.get("HISTFILE")) |value| value else try mem.concat(arena, u8, &[_][]const u8{ home_var, "/history" });

            break :hist_scope try std.Io.Dir.openFileAbsolute(io, histfile_path, .{ .mode = .read_write });
        }
    };
    defer histfile.close(io);

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
        // TODO: write conflicts to history.conflicts file
        if (hset.contains(clean_line)) continue;

        if (std.mem.startsWith(u8, clean_line, "#")) {
            if (time_stamp_flag) continue else time_stamp_flag = true;
        } else time_stamp_flag = false;

        try hset.put(clean_line, {});
        // try new_lines.append(arena, clean_line);
        try new_lines.insert(arena, 0, clean_line);

        // std.debug.print("{s}\n", .{clean_line});
    }

    // const res_file: Io.File = try Io.Dir.cwd().create(io, "~/Projects/histclean/test/result.txt", .{});
    // defer res_file.close(io);

    try histfile.setLength(io, 0);
    var result_writer = histfile.writer(io, &.{});
    const writer = &result_writer.interface;

    _ = try writer.print("{s}", .{new_lines.items[0]});
    for (new_lines.items[1..]) |item| {
        _ = try writer.print("\n{s}", .{item});
    }

    try writer.flush();

    // var file_reader = histfile.reader(init.io, &.{});
    // const reader = &file_reader.interface;
    // const bytes_read = try reader.read(&content);

    // // Prints to stderr, unbuffered, ignoring potential errors.
    // std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
    //
    // // This is appropriate for anything that lives as long as the process.
    // const arena: mem.Allocator = init.arena.allocator();
    //
    // // Accessing command line arguments:
    // const args = try init.minimal.args.toSlice(arena);
    // for (args) |arg| {
    //     std.log.info("arg: {s}", .{arg});
    // }
    //
    // // In order to do I/O operations need an `Io` instance.
    // const io = init.io;
    //
    // // Stdout is for the actual output of your application, for example if you
    // // are implementing gzip, then only the compressed bytes should be sent to
    // // stdout, not any debugging messages.
    // var stdout_buffer: [1024]u8 = undefined;
    // var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    // const stdout_writer = &stdout_file_writer.interface;
    //
    // try history_cleaner.printAnotherMessage(stdout_writer);
    //
    // try stdout_writer.flush(); // Don't forget to flush!
}

// TODO:
//  functions/flags: (function for each flag)
//   - dry-run (print output to stdout)
//   - backup (save original file into file.backup)
//   - read from file (any file given a path)
//   - write to file (any file given a path)
//   - help

fn print_help() void {
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
