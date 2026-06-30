const std = @import("std");

pub const Errors = error{
    MissingPath,
    InvalidArgument,
    CannotFindHistoryFile,
    UnsupportedShellError,
};

pub fn printDefaultErrTemp(err: anyerror) void {
    const tmp =
        \\Error: {s}!
        \\
        \\       Please fill an issue with the error log or a screenshot to
        \\           https://github.com/ABDsheikho/histclean
        \\
        \\
    ;
    std.debug.print(tmp, .{@errorName(err)});
}

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
        \\
        \\       If your file-path start with a hyphen (-)
        \\           ex: histclean -i --weird-file-name
        \\       Then a good work around is to do:
        \\           ex: histclean -i ./--weird-file-name
        \\
        \\
    ;
    std.debug.print(msg, .{});
}

pub fn printHomeVariableNotSet() void {
    const msg =
        \\Error: Neither $HISTFILE nor $HOME variables are set!
        \\       histclean can't anticipate history-file location.
        \\       Try to pass the file-path using --input option.
        \\           ex: histclean -i <file-path>
        \\
        \\
    ;
    std.debug.print(msg, .{});
}

pub fn printCannotFindHistoryFile() void {
    const msg =
        \\Error: Can't auto-detect history file using $HISTFILE!
        \\       Try to pass the file-path using --input option.
        \\           ex: histclean -i <file-path>
        \\
    ;
    std.debug.print(msg, .{});
}

pub fn printUnsupportedShell() void {
    const msg =
        \\Error: Unsupported shell.
        \\
        \\       If you would like histclean to support your shell,
        \\       then fill an issue to:
        \\           https://github.com/ABDsheikho/histclean
        \\
        \\
    ;
    std.debug.print(msg, .{});
}
