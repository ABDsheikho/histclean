#compdef histclean

typeset -A opt_args

_histclean() {
  local context state state_descr line
  typeset -A opt_args

  _arguments \
    '(-h --help)'{-h,--help}'[show help and exit]' \
    '(-v --version)'{-v,--version}'[show version and exit]' \
    '(-d --dry-run)'{-d,--dry-run}'[print cleaned output to stdout without modifying anything]' \
    '(-b --backup)'{-b,--backup}'[create a backup of the history file before modifying]' \
    '(-i --input)'{-i,--input}'[read history from file]:input file:_files' \
    '(-o --output)'{-o,--output}'[write result to file]:output file:_files' \
    '(-c --completion)'{-c,--completion}'[generate completion script for shell]:shell:(bash zsh)'
}

_histclean "$@"
