const std = @import("std");

pub const Errors = error{
    MissingPath,
    InvalidArgument,
    HomeVariableNotSet,
    EmptyInput,
};

pub fn printInvalidArgumentError() void {
    const msg =
        \\Error: Invalid Argument!
        \\
        \\
    ;
    std.debug.print(msg, .{});
}

pub fn printMissingPathError() void {
    const msg =
        \\Error: Can't parse file-path!
        \\       Did you not pass the file-path?
        \\           ex: histclean -i
        \\       Or did you pass another flag before passing the file-path?
        \\           ex: histclean -i -d
        \\       Or does the file-path start with a hyphen (-)?
        \\           ex: histclean -i -/path/to/an/error
        \\
        \\
    ;
    std.debug.print(msg, .{});
}

pub fn printHomeVariableNotSet() void {
    const msg =
        \\Error: Neither $HISTFILE nor $HOME variables are set!
        \\       Pass file-path using --input option.
        \\           ex: histclean -i <file-path>
        \\
        \\
    ;
    std.debug.print(msg, .{});
}
