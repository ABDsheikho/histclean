const std = @import("std");
const Io = std.Io;
const mem = std.mem;

const histclean = @import("root.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena: mem.Allocator = init.arena.allocator();
    const env = init.environ_map;

    // preparing stdout-handler for printing to stdout
    var stdout_writer = Io.File.stdout().writer(io, &.{});
    const stdout = &stdout_writer.interface;

    const args = histclean.parseArgs(init.minimal.args, arena) catch |err| {
        switch (err) {
            histclean.err.Errors.MissingPath => histclean.err.printMissingPathError(),
            histclean.err.Errors.InvalidArgument => histclean.err.printInvalidArgumentError(),
            else => {
                histclean.err.printDefaultErrTemp(err);
                return err;
            },
        }
        try printHelp(stdout);
        std.process.exit(1);
    };

    if (args.help) return try printHelp(stdout); // print help and exit

    run(args, io, env, arena) catch |err| {
        switch (err) {
            error.FileNotFound => histclean.err.printFileNotFound(),
            histclean.err.Errors.CannotAnticipateHistoryFile => histclean.err.printCannotAnticipateHistoryFile(),
            histclean.err.Errors.HomeVariableNotSet => histclean.err.printHomeVariableNotSet(),
            else => {
                histclean.err.printDefaultErrTemp(err);
                return err;
            },
        }
        try printHelp(stdout);
        std.process.exit(1);
    };
}

fn run(args: histclean.Args, io: Io, env: *std.process.Environ.Map, allocator: mem.Allocator) !void {
    const histfile_path: []const u8 = args.input_path orelse try anticipateHistFile(io, env, allocator);

    const histfile = try Io.Dir.openFile(Io.Dir.cwd(), io, histfile_path, .{ .mode = .read_write });
    errdefer histfile.close(io);

    // backup history file before proceeding
    if (args.backup and !args.dryRun) try backupFile(histfile_path, io);

    // read file into memory
    const file_stat = try histfile.stat(io);
    const content = try allocator.alloc(u8, file_stat.size);
    defer allocator.free(content);
    _ = try histfile.readPositionalAll(io, content, 0);

    var new_lines = try histclean.filterLines(content, allocator);
    defer new_lines.deinit(allocator);

    const output_file = try openOutputFile(args, io, &histfile);
    defer output_file.close(io);

    var result_writer = output_file.writer(io, &.{});
    try histclean.writeLines(&result_writer.interface, new_lines.items);
}

fn printHelp(writer: *Io.Writer) !void {
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
        \\                         before modifying it.
        \\  -i, --input <FILE>     Read history from the specified file instead
        \\                         of the default shell history file.
        \\  -o, --output <FILE>    Write resulted output to the specified file
        \\                         instead of overwriting the input file.
        \\
        \\The default history file is determined by the HISTFILE environment variable,
        \\or $HOME/.bash_history if HISTFILE is not set.
        \\
        \\
    ;
    try writer.print(msg, .{});
}

fn anticipateHistFile(io: Io, env: *std.process.Environ.Map, allocator: mem.Allocator) ![]const u8 {
    if (env.get("HISTFILE")) |histFile| return histFile;

    const home = env.get("HOME") orelse return histclean.err.Errors.HomeVariableNotSet;

    const bash_hist = try Io.Dir.path.join(allocator, &[_][]const u8{ home, ".bash_history" });
    if (pathExist(bash_hist, io)) |val| {
        if (val) return bash_hist;
    } else |err| return err;

    const zsh_hist = try Io.Dir.path.join(allocator, &[_][]const u8{ home, ".zsh_history" });
    if (pathExist(zsh_hist, io)) |val| {
        if (val) return zsh_hist;
    } else |err| return err;

    return histclean.err.Errors.CannotAnticipateHistoryFile;
}

fn pathExist(path: []const u8, io: Io) !bool {
    Io.Dir.access(Io.Dir.cwd(), io, path, .{}) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => return err,
    };
    return true;
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
    var buffer: [Io.Dir.max_path_bytes - 7]u8 = undefined;
    const cwd = Io.Dir.cwd();
    const dest_path = try std.fmt.bufPrint(&buffer, "{s}.backup", .{path});
    try Io.Dir.copyFile(cwd, path, cwd, dest_path, io, .{ .replace = true });
}
