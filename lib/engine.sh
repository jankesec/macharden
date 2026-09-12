#!/bin/zsh
# ==============================================================================
# macharden - lib/engine.sh
# Check registration, execution engine, scoring formulas, and state management
# ==============================================================================

# Global Registry Arrays
typeset -ga REG_IDS=()
typeset -ga REG_CATEGORIES=()
typeset -ga REG_TITLES=()
typeset -ga REG_WEIGHTS=()
typeset -ga REG_FUNCS=()

# Global Audit Result Arrays
typeset -ga RES_IDS=()
typeset -ga RES_CATEGORIES=()
typeset -ga RES_TITLES=()
typeset -ga RES_STATUSES=()
typeset -ga RES_WEIGHTS=()
typeset -ga RES_DETAILS=()
typeset -ga RES_REMEDIATIONS=()
typeset -ga RES_DURATIONS=()

# Per-check timeout threshold (seconds). Checks exceeding this emit a warning.
MACHAR_CHECK_TIMEOUT=${MACHAR_CHECK_TIMEOUT:-30}

# Skip-test list (Lynis-style skip-test=ID). INFO results; excluded from score.
typeset -ga MACHAR_SKIP_IDS=()

# Baseline/profile values. Empty values mean that the organization has not
# selected a policy for that setting. This mirrors mSCP's organization-defined
# value (ODV) model instead of silently imposing a workstation preference.
typeset -g MACHAR_PROFILE_NAME="${MACHAR_PROFILE_NAME:-}"
typeset -g MACHAR_MACHINE_ROLE="${MACHAR_MACHINE_ROLE:-}"
typeset -g MACHAR_KEYCHAIN_TIMEOUT_SECONDS="${MACHAR_KEYCHAIN_TIMEOUT_SECONDS:-}"
typeset -g MACHAR_KEYCHAIN_LOCK_ON_SLEEP="${MACHAR_KEYCHAIN_LOCK_ON_SLEEP:-}"

# Filter-check list (target specific checks, comma-separated)
typeset -ga MACHAR_FILTER_CHECK_IDS=()

# Add one or more check IDs to the filter list (e.g. HARD-18,HARD-20)
add_filter_check() {
    local raw="${1:-}"
    local piece id
    raw="${raw//‑/-}"
    raw="${raw// /}"
    [[ -z "$raw" ]] && return 0
    for piece in ${(s:,:)raw}; do
        id="${piece:u}"
        [[ -z "$id" ]] && continue
        MACHAR_FILTER_CHECK_IDS+=("$id")
    done
}

is_check_filtered() {
    local id="${1:u}"
    id="${id//‑/-}"
    if (( ${#MACHAR_FILTER_CHECK_IDS[@]} == 0 )); then
        return 0
    fi
    local f
    for f in "${MACHAR_FILTER_CHECK_IDS[@]}"; do
        if [[ "$f" == "$id" ]]; then
            return 0
        fi
    done
    return 1
}

# Add one or more check IDs to the skip list (comma-separated, case-insensitive)
# Usage: add_skip_test "HARD-08,NET-07"
add_skip_test() {
    local raw="${1:-}"
    local piece id
    raw="${raw//‑/-}"
    raw="${raw// /}"
    [[ -z "$raw" ]] && return 0
    for piece in ${(s:,:)raw}; do
        id="${piece:u}"
        [[ -z "$id" ]] && continue
        MACHAR_SKIP_IDS+=("$id")
    done
}

# Load profile settings (comments and blanks ignored).
# Supported values:
#   skip-test=ID[,ID...]
#   profile-name=NAME
#   machine-role=personal|workstation|server
#   keychain-timeout=unset|none|SECONDS
#   keychain-lock-on-sleep=unset|yes|no
# Usage: load_skip_profile /path/to/profile
load_skip_profile() {
    local file="$1"
    local line key val
    [[ -n "$file" && -f "$file" && -r "$file" ]] || return 1
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -z "$line" ]] && continue
        [[ "$line" == *=* ]] || continue
        key="${line%%=*}"
        val="${line#*=}"
        key="${key:l}"
        key="${key// /}"
        val="${val#"${val%%[![:space:]]*}"}"
        val="${val%"${val##*[![:space:]]}"}"

        case "$key" in
            skip-test)
                add_skip_test "$val"
                ;;
            profile-name)
                [[ "$val" =~ ^[[:alnum:]_.[:space:]-]{1,80}$ ]] || return 1
                MACHAR_PROFILE_NAME="$val"
                ;;
            machine-role)
                case "${val:l}" in
                    personal|workstation|server) MACHAR_MACHINE_ROLE="${val:l}" ;;
                    *) return 1 ;;
                esac
                ;;
            keychain-timeout)
                case "${val:l}" in
                    unset|"") MACHAR_KEYCHAIN_TIMEOUT_SECONDS="" ;;
                    none) MACHAR_KEYCHAIN_TIMEOUT_SECONDS="none" ;;
                    *)
                        [[ "$val" =~ ^[0-9]+$ ]] || return 1
                        (( val >= 60 && val <= 86400 )) || return 1
                        MACHAR_KEYCHAIN_TIMEOUT_SECONDS="$val"
                        ;;
                esac
                ;;
            keychain-lock-on-sleep)
                case "${val:l}" in
                    unset|"") MACHAR_KEYCHAIN_LOCK_ON_SLEEP="" ;;
                    yes|true|1) MACHAR_KEYCHAIN_LOCK_ON_SLEEP="yes" ;;
                    no|false|0) MACHAR_KEYCHAIN_LOCK_ON_SLEEP="no" ;;
                    *) return 1 ;;
                esac
                ;;
            *)
                # Profile typos must not silently weaken or alter a baseline.
                return 1
                ;;
        esac
    done < "$file"
    return 0
}

is_skipped() {
    local id="${1:u}"
    local s
    [[ -z "$id" ]] && return 1
    for s in "${MACHAR_SKIP_IDS[@]}"; do
        [[ "${s:u}" == "$id" ]] && return 0
    done
    return 1
}

# Global Score and Count Metrics
typeset -g HARDENING_INDEX=0.0
typeset -g TOTAL_POSSIBLE_POINTS=0.0
typeset -g EARNED_POINTS=0.0
typeset -gi COUNT_PASS=0
typeset -gi COUNT_WARN=0
typeset -gi COUNT_FAIL=0
typeset -gi COUNT_INFO=0
typeset -gi COUNT_SUGG=0
typeset -gi COUNT_TOTAL=0

# Register an audit check with the engine
# Usage: register_check <id> <category> <title> <weight> [func]
register_check() {
    local id="$1"
    local category="$2"
    local title="$3"
    local weight="${4:-5}"
    local func="${5:-}"

    # Default function name if omitted
    if [[ -z "$func" ]]; then
        local clean_id="${id//[-\.]/_}"
        func="audit_${clean_id}"
    fi

    REG_IDS+=("$id")
    REG_CATEGORIES+=("$category")
    REG_TITLES+=("$title")
    REG_WEIGHTS+=("$weight")
    REG_FUNCS+=("$func")
}

# Record the outcome of an audit check
# Note: Never declare 'status' as local in zsh as it is a reserved read-only parameter ($?)
# Usage: record_result <id> <category> <title> <status> <weight> <details> <remediation_cmd>
record_result() {
    local id="$1"
    local category="$2"
    local title="$3"
    local raw_status="${4:u}"
    local weight="${5:-5}"
    local details="${6:-}"
    local remediation="${7:-}"

    local normalized_status="INFO"
    case "$raw_status" in
        PASS|OK|SUCCESS)
            normalized_status="PASS"
            ;;
        WARN|WARNING)
            normalized_status="WARN"
            ;;
        FAIL|FAILURE|ERROR)
            normalized_status="FAIL"
            ;;
        INFO|INFORMATIONAL)
            normalized_status="INFO"
            ;;
        SUGG|SUGGESTION|RECOMMENDATION)
            normalized_status="SUGG"
            ;;
        *)
            normalized_status="INFO"
            ;;
    esac

    RES_IDS+=("$id")
    RES_CATEGORIES+=("$category")
    RES_TITLES+=("$title")
    RES_STATUSES+=("$normalized_status")
    RES_WEIGHTS+=("$weight")
    RES_DETAILS+=("$details")
    RES_REMEDIATIONS+=("$remediation")

    case "$normalized_status" in
        PASS) (( ++COUNT_PASS )) ;;
        WARN) (( ++COUNT_WARN )) ;;
        FAIL) (( ++COUNT_FAIL )) ;;
        INFO) (( ++COUNT_INFO )) ;;
        SUGG) (( ++COUNT_SUGG )) ;;
    esac
    (( ++COUNT_TOTAL ))

    # Live UI output when running in terminal format unless quiet mode is active
    if [[ "${MACHAR_FORMAT:-term}" == "term" && "${MACHAR_QUIET:-0}" -eq 0 ]]; then
        ui_result "$normalized_status" "$id" "$title" "$details" "$weight" "$remediation"
    fi
}

# Calculate the Hardening Index score based on weights
# Formula:
#   PASS: 100% weight
#   WARN:  50% weight
#   FAIL:   0% weight
#   INFO / SUGG: Neutral (excluded from total and earned points)
#   Index = (earned_points / total_possible_points) * 100
calculate_hardening_index() {
    local total=0.0
    local earned=0.0
    local n=${#RES_IDS[@]}

    for (( i = 1; i <= n; i++ )); do
        local st="${RES_STATUSES[i]}"
        local w="${RES_WEIGHTS[i]:-5}"
        [[ "$w" =~ ^[0-9]+(\.[0-9]+)?$ ]] || w=5.0

        case "$st" in
            PASS)
                total=$(( total + w ))
                earned=$(( earned + w ))
                ;;
            WARN)
                total=$(( total + w ))
                earned=$(( earned + (w * 0.5) ))
                ;;
            FAIL)
                total=$(( total + w ))
                ;;
            INFO|SUGG)
                # Neutral, does not penalize score
                ;;
        esac
    done

    TOTAL_POSSIBLE_POINTS=$(printf "%.1f" "$total")
    EARNED_POINTS=$(printf "%.1f" "$earned")

    if (( total > 0.0 )); then
        local raw_index=$(( (earned / total) * 100.0 ))
        HARDENING_INDEX=$(printf "%.1f" "$raw_index")
    else
        HARDENING_INDEX=100.0
    fi
}

# Run the audit suite, optionally filtered by category
# Usage: run_audit [category]
run_audit() {
    local filter_cat="${1:-all}"
    filter_cat="${filter_cat:l}"

    # Reset result tracking
    RES_IDS=()
    RES_CATEGORIES=()
    RES_TITLES=()
    RES_STATUSES=()
    RES_WEIGHTS=()
    RES_DETAILS=()
    RES_REMEDIATIONS=()
    RES_DURATIONS=()

    COUNT_PASS=0
    COUNT_WARN=0
    COUNT_FAIL=0
    COUNT_INFO=0
    COUNT_SUGG=0
    COUNT_TOTAL=0

    local num_checks=${#REG_IDS[@]}
    if (( num_checks == 0 )); then
        if [[ "${MACHAR_FORMAT:-term}" == "term" && "${MACHAR_QUIET:-0}" -eq 0 ]]; then
            ui_warn "No audit checks are currently registered."
        fi
        calculate_hardening_index
        return 0
    fi

    local current_section=""

    for (( i = 1; i <= num_checks; i++ )); do
        local id="${REG_IDS[i]}"
        local cat="${REG_CATEGORIES[i]}"
        local cat_lower="${cat:l}"
        local title="${REG_TITLES[i]}"
        local weight="${REG_WEIGHTS[i]:-5}"
        local func="${REG_FUNCS[i]}"

        # Category filter check
        if [[ "$filter_cat" != "all" && "$cat_lower" != "$filter_cat" ]]; then
            continue
        fi

        # Specific check ID filter check
        if ! is_check_filtered "$id"; then
            continue
        fi

        if is_skipped "$id"; then
            record_result "$id" "$cat" "$title" "INFO" "$weight" "Skipped via --skip-test or profile" ""
            continue
        fi

        # Print section banner if new category encountered
        if [[ "${MACHAR_FORMAT:-term}" == "term" && "${MACHAR_QUIET:-0}" -eq 0 ]]; then
            if [[ "$cat" != "$current_section" ]]; then
                current_section="$cat"
                local section_display="${(C)cat} Audit Checks"
                if [[ "${CURRENT_LANG:-en}" == "tr" ]]; then
                    section_display="$(i18n_get_category_name "$cat") Denetim Kontrolleri"
                fi
                ui_section "$section_display"
            fi
        fi

        # Find the callable function
        local clean_id="${id//[-\.]/_}"
        local clean_id_lower="${clean_id:l}"
        local clean_id_upper="${clean_id:u}"
        local func_lower="${func:l}"
        local callable=""

        if typeset -f "$func" >/dev/null 2>&1; then
            callable="$func"
        elif typeset -f "$func_lower" >/dev/null 2>&1; then
            callable="$func_lower"
        elif typeset -f "audit_${clean_id}" >/dev/null 2>&1; then
            callable="audit_${clean_id}"
        elif typeset -f "audit_${clean_id_lower}" >/dev/null 2>&1; then
            callable="audit_${clean_id_lower}"
        elif typeset -f "audit_${clean_id_upper}" >/dev/null 2>&1; then
            callable="audit_${clean_id_upper}"
        elif typeset -f "check_${clean_id}" >/dev/null 2>&1; then
            callable="check_${clean_id}"
        elif typeset -f "check_${clean_id_lower}" >/dev/null 2>&1; then
            callable="check_${clean_id_lower}"
        elif typeset -f "check_${clean_id_upper}" >/dev/null 2>&1; then
            callable="check_${clean_id_upper}"
        elif typeset -f "audit_${id}" >/dev/null 2>&1; then
            callable="audit_${id}"
        elif typeset -f "check_${id}" >/dev/null 2>&1; then
            callable="check_${id}"
        fi

        local pre_count=${#RES_IDS[@]}

        if [[ -n "$callable" ]]; then
            # Execute audit function with timing
            local check_start=$SECONDS
            "$callable" "$id" "$cat" "$title" "$weight"
            local exit_code=$?
            local check_duration=$(( SECONDS - check_start ))
            RES_DURATIONS+=("$check_duration")

            # Warn if check exceeded timeout threshold
            if (( check_duration > MACHAR_CHECK_TIMEOUT )); then
                ui_warn "Check $id took ${check_duration}s (threshold: ${MACHAR_CHECK_TIMEOUT}s)"
            fi

            # Fallback if function did not explicitly invoke record_result
            if (( ${#RES_IDS[@]} == pre_count )); then
                if (( exit_code == 0 )); then
                    record_result "$id" "$cat" "$title" "PASS" "$weight" "Check succeeded" ""
                else
                    record_result "$id" "$cat" "$title" "FAIL" "$weight" "Check failed with exit code $exit_code" ""
                fi
            fi
        else
            RES_DURATIONS+=("0")
            record_result "$id" "$cat" "$title" "WARN" "$weight" "Audit implementation '$func' not found" ""
        fi
    done

    calculate_hardening_index
    return 0
}
