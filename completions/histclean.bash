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
    esac

    local opts="-h --help -d --dry-run -b --backup -i --input -o --output"
    COMPREPLY=($(compgen -W "${opts}" -- "${cur}"))
    return 0
}

complete -F _histclean histclean
