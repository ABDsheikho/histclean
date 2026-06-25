# Changelog

## 0.1.0 — 2026-06-25

- Initial release
- Deduplicate shell history files (bash format with timestamps)
- Flags: `--help`, `--version`, `--dry-run`, `--backup`, `--input`, `--output`
- Auto-detection of history file via `$HISTFILE` or `$HOME/.bash_history`
- Man page generation via `zig build man`
- Bash completion script in `completions/`
