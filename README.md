# histclean

Clean duplicate shell commands from shell history files, while preserving
the most recent occurrence of each command.

## TL;DR

You can either download the latest binary from [releases](https://github.com/ABDsheikho/histclean/releases) page.

Or clone the repo, then build it with the Zig compiler (zig >= 0.16)

```shell
git clone https://github.com/ABDsheikho/histclean.git
cd histclean
zig build install
```

If that's your first time running `histclean`, don't forget to pass `--backup`
option to backup your history file:

```shell
histclean -b
```

## Requirements

[Zig compiler](https://ziglang.org/download/) >= 0.16

> [!NOTE]
> Since Zig is pre 1.0 release, `histclean` will always follow the latest Zig release.

## Installation

### Build

First clone the repo:

```shell
git clone https://github.com/ABDsheikho/histclean.git
cd histclean
```

Then build it using the Zig compiler:

```shell
zig build install
```

Or with a custom prefix:

```shell
zig build --prefix /usr/local
```

### Download

If you downloaded the latest binary from [releases](https://github.com/ABDsheikho/histclean/releases),
then you probably need to do the following commands:

```shell
mv histclean-v* histclean               # Clean the name
chmod +x histclean                      # Make it an executable
eval "$(histclean --completion bash)"   # Or zsh
```

### via AUR on arch linux

`histclean` is available on [the AUR](https://aur.archlinux.org/packages/histclean-bin). So you can install it using `yay` or any other AUR-helper

```shel
yay -S histclean-bin
```

Then you need to move the binary to your $PATH.

## Usage

```shell
histclean [options]
```

When run without any options, `histclean` cleans the default history file on
the system.

`histclean` determines the default history file from the `HISTFILE` environment
variable. If `HISTFILE` is not set, `histclean` exits with an error.

| Option | Description |
|---|---|
| `-h`, `--help` | Show help message and exit |
| `-v`, `--version` | Show version and exit |
| `-d`, `--dry-run` | Print the resulted output to stdout without modifying anything |
| `-b`, `--backup` | Create a `.backup` copy before modifying the file |
| `-w`, `--which-file` | Print the path to the detected history file and exit |
| `-i`, `--input <FILE>` | Read history from the specified file |
| `-o`, `--output <FILE>` | Write resulted output to the specified file |
| `-s`, `--shell <SHELL>` | Override the shell type instead of auto-detecting from `$SHELL`. See [Supported shells](#supported-shells) below. |
| `-c`, `--completion <SHELL>` | Generate completion script for the specified shell. See [Supported shells](#supported-shells) below. |

## Supported shells

- bash
- zsh

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

## License

MIT
