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
| `-s`, `--shell <SHELL>` | Override the shell type instead of auto-detecting from `$SHELL`. See [Supported shells](#shells) below. |
| `-c`, `--completion <SHELL>` | Generate completion script for the specified shell. See [Supported shells](#shells) below. |

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

## Support

### Shells

- bash
- zsh

### Platforms

- x86_64-linux
- aarch64-macos
- x86_64-macos
- aarch64-freebsd
- x86_64-freebsd

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

## FAQ

<details>
	<summary>
		Doesn't this tool can be done in a one-liner POSIX shell?
	</summary>
Yes, a core logic can be done in one line as:

```shell
tac "$HISTFILE" | awk '!seen[$0]++' | tac
```

If you prefer this kind of quick hacks, then go for it.

</details>

<details>
	<summary>
		Why 1k LoC in Zig when you can write it in a much smaller Python or JS?
	</summary>
	<p>
		Shorter != better. LoC is a cost, not a virtue. What matters is what ships.
		Python and JS add a runtime. histclean is a statically-linked binary meant to
		be installed once and forgotten.
	</p>
</details>

<details>
	<summary>
		This tool doesn't have <code>--watch</code>
		option, what's good about it?
	</summary>
	<p>
		<code>--watch</code>
		turns a millisecond task into a daemon. That's what your shell's
		<code>HISTCONTROL</code>
		settings are for. histclean is for bulk cleanup, and you can
		run it from cron or a hook if you need to.
	</p>
	<p>
		Not every CLI needs to sit in your terminal.
	</p>
</details>

<details>
	<summary>
		I downloaded the binary but can't run it. What's wrong?
	</summary>
	<p>
		You probably need to <code>chmod +x</code>
		it, then move it to a directory in your <code>$PATH</code>
		like <code>~/.local/bin</code>
		or <code>/usr/local/bin</code>.
	</p>
</details>

<details>
	<summary>
		I ran histclean but my history file wasn't modified. Why?
	</summary>
	<p>
		Most likely <code>HISTFILE</code>
		isn't set, or histclean is targeting a different file
		than you expect. To confirm that it's pointing at the right file, run:
	</p>

```shell
histclean --which-file
```

</details>

<details>
	<summary>
		Running <code>histclean</code>
		broke my history file. What happened?
	</summary>
	<p>
		histclean only keeps the most recent occurrence of each command and preserves
		timestamp lines, and it doesn't invent or reorder lines.
		If your history file has entries that seem wrong, they were already in your file.
	</p>
	<p>
		Restore your backup if you used <code>--backup</code>.
		If you didn't, consider file-recovery tools if necessary,
		but the data was already in that state before histclean ran.
	</p>
</details>

<details>
	<summary>
		Do I need Zig on my system to have this command?
	</summary>
	<p>
		If your OS/Architecture is listed on
		<a href="#Platforms">supported platforms</a>,
		then no. The releases page provides a prebuilt binary. Download it,
		<code>chmod +x</code>
		it, done. <br>
		But if you're on a different OS/architecture,
		you'll need the Zig compiler to build from source.
	</p>
</details>

<details>
	<summary>
		Does histclean work with fish shell?
	</summary>
	<p>
		No. Fish already handles this natively, and it never stores duplicate history
		entries to begin with. You don't need histclean for that, and that's why we
		currently don't support it.
	</p>
</details>

<details>
	<summary>
		Can I ask to support my shell?
	</summary>
	<p>
		Yes, just fill an issue and provide a history format or history sample,
		and I'll work on it.
	</p>
</details>

<details>
	<summary>
		Does histclean handle history files larger than X?
	</summary>
	<p>
		Nothing you're likely to hit. A history file with 100k lines (~10MB) would use
		maybe 20-30MB of RAM when loaded fully into memory, which is well within range.
		Extremely large files (hundreds of MB) would be constrained by available memory.
	</p>
</details>

<details>
	<summary>
		Can I use histclean with a custom/non-standard history file path?
	</summary>
	<p>
		Yes. By default histclean reads <code>$HISTFILE</code>. If yours is non-standard,
		just make sure it's exported. Or use <code>--input</code>
		to bypass env detection entirely and target any file.
	</p>
</details>

<details>
	<summary>
		I use bash as my shell, but I passed <code>--input</code>
		to a zsh history file and nothing changed. Why?
	</summary>
	<p>
		By default, histclean detects your shell (and its parsing mechanism) from
		<code>$SHELL</code>, not from the file you pass with <code>--input</code>. So a zsh file gets parsed
		with bash rules. Pass <code>--shell zsh</code>
		alongside <code>--input</code>
		to override.
	</p>
</details>

## License

MIT
