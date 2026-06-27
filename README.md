# histclean

Clean duplicate shell commands from shell history files, while preserving
the most recent occurrence of each command.

## TL;DR

Clone the repo, then build it with the Zig compiler (zig >= 0.16)

```shell
git clone githu
cd histclean
zig build install
```

## Requirements

[Zig compiler](https://ziglang.org/download/) >= 0.16

## Installation

```shell
zig build install
```

Or with a custom prefix:

```shell
zig build --prefix /usr/local
```

## Usage

```shell
histclean [options]
```

When run without any options, `histclean` cleans the default history file on
the system.

`histclean` determines the default history file from the `HISTFILE` environment
variable, falling back to `$HOME/.bash_history` or `$HOME/.zsh_history` if
`HISTFILE` is not set.

| Option | Description |
|---|---|
| `-h`, `--help` | Show help message and exit |
| `-v`, `--version` | Show version and exit |
| `-d`, `--dry-run` | Print the resulted output to stdout without modifying anything |
| `-b`, `--backup` | Create a `.backup` copy before modifying the file |
| `-i`, `--input <FILE>` | Read history from the specified file |
| `-o`, `--output <FILE>` | Write resulted output to the specified file |
| `-c`, `completion <shell>` | Generate completion script for the specified shell (bash, zsh) |

## Examples

```shell
# Deduplicate the default history file in-place
histclean

# Preview what would be removed
histclean --dry-run

# Clean a specific history file with a backup
histclean --input ~/.zsh_history --backup

# Write cleaned output to a new file
histclean --input ~/.bash_history --output ~/cleaned_history
```

## How It Works

`histclean` scans the history file backwards, keeping only the most recent
occurrence of each unique command line. Timestamp lines (prefixed with `#`)
are preserved for their associated commands, and orphaned consecutive
timestamps are collapsed.

## Build Options

```shell
zig build                 # Debug build
zig build test            # Run unit and integration tests
zig build man             # Generate man page (requires scdoc)
```

Optimization modes:

```shell
zig build -Doptimize=ReleaseSafe
zig build -Doptimize=ReleaseFast
zig build -Doptimize=ReleaseSmall
```

## Shell Completions

Shell completion is available in `completions/` directory.

```shell
# Source it (per session)
source completions/histclean.bash

# Or install system-wide (requires bash-completion v2.x)
sudo cp completions/histclean.bash /usr/share/bash-completion/completions/histclean
```

You can also generate the completion script using the `--completion` option by
providing the associated shell (`bash`, `zsh`).

```shell
eval "$(histclean --completion zsh)"
```

## Limitations

Currently, histclean only implements the `.bash_history` file format with
its timestamps. It works correctly with `EXTENDED_HISTORY` turned off.
There is no implementation for parsing `.zsh_history` files with their
timestamps.

## License

MIT
