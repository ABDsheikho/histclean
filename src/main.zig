const std = @import("std");
const Io = std.Io;
const mem = std.mem;

const histclean = @import("histclean");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena: mem.Allocator = init.arena.allocator();
    const env = init.environ_map;

    const args = histclean.parseArgs(init.minimal.args, arena) catch |err| switch (err) {
        error.MissingPath => {
            printError();
            printHelp();
            std.process.exit(1);
        },
        else => std.process.exit(1),
    };

    if (args.help) return printHelp(); // print help and exit

    const histfile_path = try getHistoryPath(args.input_path, env, arena);

    const histfile = try Io.Dir.openFile(Io.Dir.cwd(), io, histfile_path, .{ .mode = .read_write });
    errdefer histfile.close(io);

    // backup history file before proceeding
    if (args.backup and !args.dryRun) try backupFile(histfile_path, io);

    // read file into memory
    const file_stat = try histfile.stat(io);
    const content = try arena.alloc(u8, file_stat.size);
    defer arena.free(content);
    _ = try histfile.readPositionalAll(io, content, 0);

    var new_lines = try histclean.filterLines(content, arena);
    defer new_lines.deinit(arena);

    const output_file = try openOutputFile(args, io, &histfile);
    defer output_file.close(io);

    var result_writer = output_file.writer(io, &.{});
    try histclean.writeLines(&result_writer.interface, new_lines);
}

fn printError() void {
    const msg =
        \\Error: can't parse file-path!
        \\       Did you pass another flag before passing file-path?
        \\           ex: histclean -i -d     -> error
        \\       Or does the file-path start with a hyphen (-)?
        \\           ex: histclean -i -/path/to/error
        \\
        \\
    ;
    std.debug.print(msg, .{});
}

fn printHelp() void {
    const msg =
        \\Usage: histclean [options]
        \\
        \\Clean duplicate shell commands from history files in-place, while
        \\preserving the most recent unique occurrence of each command.
        \\
        \\Options:
        \\  -h, --help             Show this help message and exit
        \\  -d, --dry-run          Print the resulted output to stdout without
        \\                         modifying anything.
        \\  -b, --backup           Create a .backup copy of the history file
        \\                         before modifying it
        \\  -i, --input <FILE>     Read history from the specified file instead
        \\                         of the default shell history file
        \\  -o, --output <FILE>    Write resulted output to the specified file
        \\                         instead of overwriting the input file
        \\
        \\The default history file is determined by the HISTFILE environment variable,
        \\or $HOME/history if HISTFILE is not set.
        \\
        \\
    ;
    std.debug.print("{s}", .{msg});
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
    return error.HistoryFileNotFound;
}

fn openOutputFile(args: histclean.Args, io: Io, defaultFile: *const Io.File) !Io.File {
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

test {}
