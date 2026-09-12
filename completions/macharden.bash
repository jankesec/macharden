# bash completion for macharden                             -*- shell-script -*-
# ==============================================================================
# macharden - Bash Completion Script
# Native completion definition for macOS Security Hardening & Audit Scanner
# ==============================================================================

_macharden_completions() {
    local cur prev words cword
    if declare -F _init_completion >/dev/null 2>&1; then
        _init_completion -s || return
    else
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
        words=("${COMP_WORDS[@]}")
        cword=$COMP_CWORD
    fi

    local categories="hardening network secrets persistence all"
    local formats="term json markdown html"
    local compliance_frameworks="cis nist mitre all"
    local daemon_schedules="daily weekly monthly hourly on-login"
    local all_flags="-h --help -v --version -c --category -f --format -l --lang -o --output -q --quiet --fix --generate-fix --no-color --compliance --daemon-install --daemon-uninstall --daemon-status --alert --skip-test --profile --no-profile"

    case "${prev}" in
        -l|--lang)
            COMPREPLY=( $(compgen -W "en tr" -- "${cur}") )
            return 0
            ;;
        -c|--category)
            COMPREPLY=( $(compgen -W "${categories}" -- "${cur}") )
            return 0
            ;;
        -f|--format)
            COMPREPLY=( $(compgen -W "${formats}" -- "${cur}") )
            return 0
            ;;
        --compliance)
            COMPREPLY=( $(compgen -W "${compliance_frameworks}" -- "${cur}") )
            return 0
            ;;
        --daemon-install)
            COMPREPLY=( $(compgen -W "${daemon_schedules}" -- "${cur}") )
            return 0
            ;;
        --profile)
            if declare -F _filedir >/dev/null 2>&1; then
                _filedir
            else
                COMPREPLY=( $(compgen -f -- "${cur}") )
            fi
            return 0
            ;;
        -o|--output|--generate-fix)
            if declare -F _filedir >/dev/null 2>&1; then
                _filedir
            else
                COMPREPLY=( $(compgen -f -- "${cur}") )
            fi
            return 0
            ;;
    esac

    if [[ "${cur}" == -* ]]; then
        COMPREPLY=( $(compgen -W "${all_flags}" -- "${cur}") )
        return 0
    fi
}

complete -F _macharden_completions macharden
