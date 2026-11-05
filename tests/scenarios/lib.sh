#!/bin/zsh
# ==============================================================================
# macharden - tests/scenarios/lib.sh
# Scenario DSL for the evidence contract (docs/ARCHITECTURE.md, "Check contract").
#
# A scenario runs ONE registered check in a sandbox:
#   * PATH holds only the shims the scenario defines plus the host tools in base_tools.txt, so every
#     other command (defaults, launchctl, netstat, ...) is "command not found";
#   * HOME and MACHAR_FS_ROOT point at empty temporary directories;
#   * CI and GITHUB_ACTIONS are unset unless the scenario sets them.
# The check can only see the evidence the scenario provides.
# ==============================================================================

typeset -gi SC_TOTAL=0 SC_PASSED=0 SC_FAILED=0
typeset -gA SC_COUNT SC_RULES
typeset -ga SC_ENV SC_NOCALL SC_SEAMS_COMPLETE
typeset -g SC_ID="" SC_DESC="" SC_FUNC="" SC_DIR="" SC_BIN="" SC_ROOT="" SC_HOME="" SC_LOG=""
typeset -g SC_EXPECT="" SC_DETAILS_RE="" SC_WHY=""
typeset -g SC_LIB_DIR="${${(%):-%x}:A:h}"

# Quote a string for a POSIX sh single-quoted context.
sc_q() {
    local s="$1" q="'"
    print -r -- "'${s//$q/$q\\$q$q}'"
}

# sc_assert <0|1> "<description>" ["<detail>"]: record one assertion (0 = pass).
sc_assert() {
    (( ++SC_TOTAL ))
    if [[ "$1" == "0" ]]; then
        (( ++SC_PASSED ))
        printf "  \033[92m✔ PASS\033[0m: %s\n" "$2"
    else
        (( ++SC_FAILED ))
        printf "  \033[91m✖ FAIL\033[0m: %s\n" "$2"
        [[ -n "${3:-}" ]] && printf "         \033[2m%s\033[0m\n" "$3"
    fi
}

# sc_judge <expected> <actual status> <details> <details regex>: sets SC_WHY, returns 1 on a mismatch.
# NOT_PASS accepts any status except PASS (and a missing result).
sc_judge() {
    local expected="$1" actual="$2" details="$3" re="${4:-}"
    SC_WHY=""
    if [[ "$expected" == "NOT_PASS" ]]; then
        if [[ "$actual" == "PASS" || "$actual" == "NONE" || "$actual" == "MISSING" ]]; then
            SC_WHY="expected anything but PASS, got $actual ($details)"
            return 1
        fi
    elif [[ "$actual" != "$expected" ]]; then
        SC_WHY="expected $expected, got $actual ($details)"
        return 1
    fi
    if [[ -n "$re" && ! "$details" =~ $re ]]; then
        SC_WHY="details '$details' do not match /$re/"
        return 1
    fi
    return 0
}

# scenario_begin <check id> "<description>" [function]: start a scenario in a fresh sandbox.
# The optional function overrides the registry lookup (used by the harness self-test).
scenario_begin() {
    SC_ID="$1"; SC_DESC="$2"; SC_FUNC="${3:-}"
    SC_DIR=$(mktemp -d "${TMPDIR:-/tmp}/machar_scenario.XXXXXX")
    SC_BIN="$SC_DIR/bin"; SC_ROOT="$SC_DIR/root"; SC_HOME="$SC_DIR/home"; SC_LOG="$SC_DIR/calls.log"
    mkdir -p "$SC_BIN" "$SC_ROOT" "$SC_HOME"
    : > "$SC_LOG"
    SC_ENV=(); SC_NOCALL=(); SC_RULES=(); SC_EXPECT=""; SC_DETAILS_RE=""
    # Note: never name a zsh variable "path": it is tied to PATH, so assigning it breaks command lookup.
    local tool tool_path
    while IFS= read -r tool; do
        [[ -z "$tool" || "$tool" == \#* ]] && continue
        tool_path=$(command -v "$tool" 2>/dev/null) || continue
        [[ "$tool_path" == /* ]] && ln -s "$tool_path" "$SC_BIN/$tool"
    done < "$SC_LIB_DIR/base_tools.txt"
}

# shim <command> [--when TEXT] [--out TEXT] [--err TEXT] [--exit N]
# Adds a rule to a fake command. A rule matches when the argument line contains TEXT (no --when matches
# everything); the first matching rule wins; no match exits 1. Every call is appended to the call log.
shim() {
    local cmd="$1"; shift
    local when="" out="" err="" code=0 has_out=0 has_err=0
    while (( $# )); do
        case "$1" in
            --when) when="$2"; shift 2 ;;
            --out)  out="$2"; has_out=1; shift 2 ;;
            --err)  err="$2"; has_err=1; shift 2 ;;
            --exit) code="$2"; shift 2 ;;
            *) print -u2 "shim: unknown option '$1'"; return 2 ;;
        esac
    done
    local pat='*'
    [[ -n "$when" ]] && pat="*$(sc_q "$when")*"
    local body=""
    (( has_out )) && body+="printf '%s\\n' $(sc_q "$out"); "
    (( has_err )) && body+="printf '%s\\n' $(sc_q "$err") >&2; "
    body+="exit $code"
    SC_RULES[$cmd]+="  $pat) $body ;;"$'\n'
}

# fs <absolute path> [content]: a file under the fake root (a trailing / creates a directory).
fs() {
    local target="$SC_ROOT$1"
    if [[ "$1" == */ ]]; then
        mkdir -p "$target"
    else
        mkdir -p "${target:h}"
        print -r -- "${2-}" > "$target"
    fi
}

# home <relative path> [content]: a file under the fake HOME (a trailing / creates a directory).
home() {
    local target="$SC_HOME/$1"
    if [[ "$1" == */ ]]; then
        mkdir -p "$target"
    else
        mkdir -p "${target:h}"
        print -r -- "${2-}" > "$target"
    fi
}

fs_mode()   { chmod "$1" "$SC_ROOT$2"; }
home_mode() { chmod "$1" "$SC_HOME/${2%/}"; }

# without <tool>: remove a base tool from the sandbox.
without() { rm -f "$SC_BIN/$1"; }

# sc_env NAME=VALUE: set an environment variable for the check.
sc_env() { SC_ENV+=("$1"); }

# expect <STATUS|NOT_PASS> [--details REGEX]
expect() {
    SC_EXPECT="$1"; shift
    [[ "${1:-}" == "--details" ]] && SC_DETAILS_RE="$2"
    return 0
}

# expect_no_call <command>: fail when the check ran that command.
expect_no_call() { SC_NOCALL+=("$1"); }

# seams_complete <check id>: declare that every evidence source of the check goes through the sandbox.
seams_complete() { SC_SEAMS_COMPLETE+=("$1"); }

# Write the shim scripts for the rules collected so far.
sc_write_shims() {
    local cmd f
    for cmd in ${(k)SC_RULES}; do
        f="$SC_BIN/$cmd"
        rm -f "$f"                          # a shim replaces a base tool of the same name
        {
            print -r -- '#!/bin/sh'
            print -r -- "printf '%s %s\\n' $(sc_q "$cmd") \"\$*\" >> $(sc_q "$SC_LOG")"
            print -r -- 'case "$*" in'
            print -rn -- "${SC_RULES[$cmd]}"
            print -r -- '  *) exit 1 ;;'
            print -r -- 'esac'
        } > "$f"
        chmod +x "$f"
    done
}

# Run one registered check (or the given function) and print "STATUS<TAB>DETAILS".
sc_run_check() {
    local id="$1" func="${2:-}" i
    RES_IDS=(); RES_CATEGORIES=(); RES_TITLES=(); RES_STATUSES=(); RES_WEIGHTS=(); RES_DETAILS=(); RES_REMEDIATIONS=()
    if [[ -n "$func" ]]; then
        "$func" "$id" "selftest" "$id" 5
    else
        for (( i = 1; i <= ${#REG_IDS[@]}; i++ )); do
            if [[ "${REG_IDS[i]}" == "$id" ]]; then
                "${REG_FUNCS[i]}" "$id" "${REG_CATEGORIES[i]}" "${REG_TITLES[i]}" "${REG_WEIGHTS[i]}"
                break
            fi
        done
    fi
    if (( ${#RES_STATUSES[@]} == 0 )); then
        print -r -- "NONE"$'\t'"the check recorded no result"
        return 0
    fi
    print -r -- "${RES_STATUSES[-1]}"$'\t'"${RES_DETAILS[-1]}"
}

# Run the current scenario's check in the sandbox and print "STATUS<TAB>DETAILS".
sc_exec() {
    local id="$1" func="${2:-}"
    sc_write_shims
    (
        export PATH="$SC_BIN" HOME="$SC_HOME" MACHAR_FS_ROOT="$SC_ROOT" MACHAR_FORMAT=json MACHAR_QUIET=1
        # Tools called by absolute path cannot be shadowed by PATH: their seams default into the fake root
        # (nonexistent unless the scenario creates it), so a scenario never reaches the host's real tool.
        export MACHAR_SOCKETFILTERFW="$SC_ROOT/usr/libexec/ApplicationFirewall/socketfilterfw"
        unset CI GITHUB_ACTIONS
        hash -r
        local kv
        for kv in "${SC_ENV[@]}"; do export "$kv"; done
        sc_run_check "$id" "$func" 2>/dev/null
    )
}

# Finish the scenario: run it, judge it, report it, clean up.
scenario_end() {
    # Note: never name a zsh variable "status": it is a reserved read-only parameter ($?).
    local line outcome details verdict="PASS" c
    line=$(sc_exec "$SC_ID" "$SC_FUNC")
    outcome="${line%%$'\t'*}"
    details="${line#*$'\t'}"
    sc_judge "$SC_EXPECT" "$outcome" "$details" "$SC_DETAILS_RE" || verdict="FAIL"
    for c in "${SC_NOCALL[@]}"; do
        if grep -q "^$c " "$SC_LOG" 2>/dev/null; then
            verdict="FAIL"
            SC_WHY="$c was called but must not be"
        fi
    done
    SC_COUNT[$SC_ID]=$(( ${SC_COUNT[$SC_ID]:-0} + 1 ))
    if [[ "$verdict" == "PASS" ]]; then
        sc_assert 0 "$SC_ID $SC_DESC"
    else
        sc_assert 1 "$SC_ID $SC_DESC" "$SC_WHY"
    fi
    rm -rf "$SC_DIR"
}

sc_summary() {
    echo ""
    echo "\033[1m======================================================================\033[0m"
    printf "\033[1mScenario Test Results:\033[0m Total: %d | \033[92mPassed: %d\033[0m | \033[91mFailed: %d\033[0m\n" \
        "$SC_TOTAL" "$SC_PASSED" "$SC_FAILED"
    echo "\033[1m======================================================================\033[0m"
    # A run in which no scenario executed (for example because a scenario file failed to load) is a failure.
    if (( SC_TOTAL == 0 )); then
        printf "  \033[91m✖ FAIL\033[0m: no scenario ran\n"
        return 1
    fi
    (( SC_FAILED == 0 ))
}
