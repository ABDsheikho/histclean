const std = @import("std");

pub const Errors = error{
    MissingPath,
    InvalidArgument,
    HomeVariableNotSet,
    CannotAnticipateHistoryFile,
};

pub fn printDefaultErrTemp(err: anyerror) void {
    const tmp =
        \\Error: {s}!
        \\
        \\       Please fill an issue with the error log or a screenshot to
        \\           www.github.com/ABDsheikho/histclean
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

pub fn printCannotAnticipateHistoryFile() void {
    const msg =
        \\Error: Can't anticipate history file location!
        \\       Try to pass the file-path using --input option.
        \\           ex: histclean -i <file-path>
        \\
    ;
    std.debug.print(msg, .{});
}

pub fn printFileNotFound() void {
    const msg =
        \\Error: File not found!
        \\       Make sure that the file-path do exist.
        \\
    ;
    std.debug.print(msg, .{});
}
