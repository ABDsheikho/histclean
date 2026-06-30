_histclean() {
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case "${prev}" in
        -i|--input|-o|--output)
            COMPREPLY=($(compgen -f -- "${cur}"))
            return 0
            ;;
        -s|--shell|-c|--completion)
            COMPREPLY=($(compgen -W "bash zsh" -- "${cur}"))
            return 0
            ;;
    esac

    local opts="-h --help -v --version -d --dry-run -b --backup -w --which-file -s --shell -c --completion -i --input -o --output"
    COMPREPLY=($(compgen -W "${opts}" -- "${cur}"))
    return 0
}

complete -F _histclean histclean
