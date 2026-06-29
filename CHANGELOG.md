# Changelog

## 0.2.1 — 2026-06-29

- Add `--which-file` / `-w` flag to print the path to the detected history file
- `filterLines` now returns `![]const []const u8` instead of `std.ArrayList` for a more
  slice-oriented and allocator-flexible API
- Rename test history files to `history.bash` / `history.bash.expected` to prepare for
  multi-shell test support
- Fix typos and small code tweaks
- README: document Zig version compatibility, AUR installation, and binary downloads

## 0.2.0 — 2026-06-27

- Add `--completion` / `-c` flag to generate completion scripts for bash and zsh
- Add zsh completion script in `completions/`
- Add tests for completion flag parsing, edge cases, and integration paths
- Restructure README headings for better flow; add TL;DR and Limitations sections
- Update man page to document new flags

## 0.1.0 — 2026-06-25

- Initial release
- Deduplicate shell history files (bash format with timestamps)
- Flags: `--help`, `--version`, `--dry-run`, `--backup`, `--input`, `--output`
- Auto-detection of history file via `$HISTFILE` or `$HOME/.bash_history`
- Man page generation via `zig build man`
- Bash completion script in `completions/`
