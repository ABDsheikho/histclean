# histclean

Clean duplicate shell commands from shell history files, preserving the most
recent occurrence of each command.

## Installation

Requires **Zig 0.16.0** or later.

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

The default history file is determined by the `HISTFILE` environment variable,
or `$HOME/.bash_history` if `HISTFILE` is not set.

| Option | Description |
|---|---|
| `-h`, `--help` | Show help message and exit |
| `-v`, `--version` | Show version and exit |
| `-d`, `--dry-run` | Print cleaned output to stdout, don't modify anything |
| `-b`, `--backup` | Create a `.backup` copy before modifying the file |
| `-i`, `--input <FILE>` | Read history from the specified file |
| `-o`, `--output <FILE>` | Write cleaned output to the specified file |

## Shell Completions

Bash completion is available in `completions/histclean.bash`.

```shell
# Source it (per session)
source completions/histclean.bash

# Or install system-wide (requires bash-completion v2.x)
sudo cp completions/histclean.bash /usr/share/bash-completion/completions/histclean
```

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

## How It Works

histclean scans the history file backwards, keeping only the most recent
occurrence of each unique command line. Timestamp lines (prefixed with `#`)
are preserved for their associated commands, and orphaned consecutive
timestamps are collapsed.

## License

MIT
