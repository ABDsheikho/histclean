const std = @import("std");
const Io = std.Io;
const mem = std.mem;

const histclean = @import("histclean");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena: mem.Allocator = init.arena.allocator();

    const env = init.environ_map;
    const home_var = env.get("HOME").?;
    const histfile_var: []const u8 = if (env.get("HISTFILE")) |value| value else try mem.concat(arena, u8, &[_][]const u8{ home_var, "/history" });

    defer std.debug.print("Home is: {s}\n", .{home_var});
    defer std.debug.print("History is: {s}\n", .{histfile_var});
    defer std.debug.print("\n\n\n", .{});

    // var v : std.Io.File = .stdin();

    // const histfile_file = try std.Io.Dir.openFileAbsolute(io, histfile_var, .{ .mode = .read_only });
    const histfile_file = try std.Io.Dir.openFile(Io.Dir.cwd(), io, "./test/history", .{ .mode = .read_write });
    defer histfile_file.close(io);

    const file_stat = try histfile_file.stat(io);

    const content = try arena.alloc(u8, file_stat.size);
    defer arena.free(content);
    _ = try histfile_file.readPositionalAll(io, content, 0);

    var backward_lines = mem.splitBackwardsAny(u8, content, "\n\r");

    var hset: std.StringHashMap(void) = .init(arena);

    var new_lines: std.ArrayList([]const u8) = .empty;
    defer new_lines.deinit(arena);

    var i: usize = 0;
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
        try new_lines.insert(arena, 0, line);

        // std.debug.print("{s}\n", .{clean_line});
        i += 1;
    }

    i -= 1;
    defer std.debug.print("\nNumber of lines: {}\n", .{i});

    // const res_file: Io.File = try Io.Dir.cwd().create(io, "~/Projects/histclean/test/result.txt", .{});
    // defer res_file.close(io);

    try histfile_file.setLength(io, 0);
    var result_writer = histfile_file.writer(io, &.{});
    const writer = &result_writer.interface;

    _ = try writer.print("{s}", .{new_lines.items[0]});
    for (new_lines.items[1..]) |item| {
        _ = try writer.print("\n{s}", .{item});
    }

    try writer.flush();

    // var file_reader = histfile_file.reader(init.io, &.{});
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
