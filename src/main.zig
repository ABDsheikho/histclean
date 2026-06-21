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
    const env = init.environ_map;

    const args = try parseArgs(init.minimal.args, arena);

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

fn parseArgs(args: std.process.Args, allocator: mem.Allocator) !Args {
    var args_iter = try args.iterateAllocator(allocator);
    defer args_iter.deinit();

    _ = args_iter.next(); // discard binary name

    var arg_struct = Args{};
    while (args_iter.next()) |arg| {
        if (mem.eql(u8, arg, "-h") or mem.eql(u8, arg, "--help")) arg_struct.help = true;
        if (mem.eql(u8, arg, "-d") or mem.eql(u8, arg, "--dry-run")) arg_struct.dryRun = true;
        if (mem.eql(u8, arg, "-b") or mem.eql(u8, arg, "--backup")) arg_struct.backup = true;
        if (mem.eql(u8, arg, "-i") or mem.eql(u8, arg, "--input")) assignPath(&arg_struct.input_path, &args_iter);
        if (mem.eql(u8, arg, "-o") or mem.eql(u8, arg, "--output")) assignPath(&arg_struct.output_path, &args_iter);
    }
    return arg_struct;
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

fn assignPath(str: *?[]const u8, args_iter: *std.process.Args.Iterator) void {
    if (args_iter.next()) |path| check: {
        if (mem.startsWith(u8, path, "-")) break :check;
        str.* = path;
        return;
    }
    const error_msg =
        \\Error: can't parse file-path!
        \\       Did you pass another flag before passing file-path?
        \\           ex: histclean -i -d     -> error
        \\       Or does the file-path start with a hyphen (-)?
        \\           ex: histclean -i -/path/to/error
        \\
        \\
    ;
    std.debug.print(error_msg, .{});
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
    return error.HistoryFileNotFound;
}

fn openOutputFile(args: Args, io: Io, defaultFile: *const Io.File) !Io.File {
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

test { }
