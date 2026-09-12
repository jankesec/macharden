#!/bin/zsh
# ==============================================================================
# macharden - lib/diff.sh
# Baseline Drift Engine, Diff Calculation, and Historical Posture Comparator
# ==============================================================================

# Ensure execution under zsh or bash
if [ -z "${ZSH_VERSION:-}" ] && [ -z "${BASH_VERSION:-}" ]; then
    echo "Warning: diff.sh is designed for zsh or bash" >&2
fi

# Ensure rating text helper is available
if ! typeset -f _get_rating_text >/dev/null 2>&1; then
    _get_rating_text() {
        local score="${1:-0}"
        local s=0
        [[ "$score" =~ ^[0-9]+ ]] && s=${score%%.*}
        if (( s >= 85 )); then echo "EXCELLENT / HARDENED"
        elif (( s >= 70 )); then echo "GOOD / ACCEPTABLE"
        elif (( s >= 50 )); then echo "FAIR / NEEDS ATTENTION"
        else echo "CRITICAL / VULNERABLE"; fi
    }
fi

# Fallback UI color variables if ui.sh was not pre-sourced
if [[ "${MACHAR_NO_COLOR:-0}" -eq 1 ]] || [[ -n "${NO_COLOR:-}" ]]; then
    COLOR_RESET=""
    COLOR_BOLD=""
    COLOR_DIM=""
    COLOR_RED=""
    COLOR_GREEN=""
    COLOR_YELLOW=""
    COLOR_BLUE=""
    COLOR_MAGENTA=""
    COLOR_CYAN=""
    COLOR_WHITE=""
    COLOR_BRED=""
    COLOR_BGREEN=""
    COLOR_BYELLOW=""
    COLOR_BCYAN=""
    COLOR_BMAGENTA=""
elif [[ -z "${COLOR_BOLD:-}" ]]; then
    COLOR_RESET=$'\033[0m'
    COLOR_BOLD=$'\033[1m'
    COLOR_DIM=$'\033[2m'
    COLOR_RED=$'\033[31m'
    COLOR_GREEN=$'\033[32m'
    COLOR_YELLOW=$'\033[33m'
    COLOR_BLUE=$'\033[34m'
    COLOR_MAGENTA=$'\033[35m'
    COLOR_CYAN=$'\033[36m'
    COLOR_WHITE=$'\033[37m'
    COLOR_BRED=$'\033[91m'
    COLOR_BGREEN=$'\033[92m'
    COLOR_BYELLOW=$'\033[93m'
    COLOR_BCYAN=$'\033[96m'
    COLOR_BMAGENTA=$'\033[95m'
fi

# ==============================================================================
# Global Baseline State Variables
# ==============================================================================
typeset -g BASELINE_FILE=""
typeset -g BASELINE_TIMESTAMP=""
typeset -g BASELINE_HOSTNAME=""
typeset -g BASELINE_USER=""
typeset -g BASELINE_OS=""
typeset -g BASELINE_SCORE="0.0"
typeset -g BASELINE_RATING=""
typeset -gi BASELINE_TOTAL=0
typeset -gi BASELINE_PASS=0
typeset -gi BASELINE_WARN=0
typeset -gi BASELINE_FAIL=0
typeset -gi BASELINE_INFO=0
typeset -gi BASELINE_SUGG=0

# Baseline Check Lookups
typeset -ga BASELINE_CHECK_IDS=()
typeset -gA BASELINE_STATUS=()
typeset -gA BASELINE_TITLE=()
typeset -gA BASELINE_CATEGORY=()
typeset -gA BASELINE_DETAILS=()
typeset -gA BASELINE_WEIGHT=()
typeset -gA BASELINE_REMEDIATION=()

# ==============================================================================
# Global Diff & Drift State Variables
# ==============================================================================
typeset -g DIFF_SCORE_DELTA="0.0"
typeset -g DIFF_SCORE_DELTA_FORMATTED="0.0%"
typeset -gi DIFF_COUNT_REGRESSIONS=0
typeset -gi DIFF_COUNT_FIXED=0
typeset -gi DIFF_COUNT_UNCHANGED=0
typeset -g DIFF_JSON_DATA=""

# New Regressions: baseline PASS/WARN -> current FAIL, or baseline PASS -> current WARN
typeset -ga DIFF_REGRESSIONS_IDS=()
typeset -ga DIFF_REGRESSIONS_CATEGORIES=()
typeset -ga DIFF_REGRESSIONS_TITLES=()
typeset -ga DIFF_REGRESSIONS_OLD=()
typeset -ga DIFF_REGRESSIONS_NEW=()
typeset -ga DIFF_REGRESSIONS_WEIGHTS=()
typeset -ga DIFF_REGRESSIONS_DETAILS=()

# Remediated Issues: baseline FAIL/WARN -> current PASS
typeset -ga DIFF_FIXED_IDS=()
typeset -ga DIFF_FIXED_CATEGORIES=()
typeset -ga DIFF_FIXED_TITLES=()
typeset -ga DIFF_FIXED_OLD=()
typeset -ga DIFF_FIXED_NEW=()
typeset -ga DIFF_FIXED_WEIGHTS=()
typeset -ga DIFF_FIXED_DETAILS=()

# Unchanged findings
typeset -ga DIFF_UNCHANGED_IDS=()
typeset -ga DIFF_UNCHANGED_TITLES=()
typeset -ga DIFF_UNCHANGED_STATUS=()

# Reset diff state
diff_reset() {
    BASELINE_FILE=""
    BASELINE_TIMESTAMP=""
    BASELINE_HOSTNAME=""
    BASELINE_USER=""
    BASELINE_OS=""
    BASELINE_SCORE="0.0"
    BASELINE_RATING=""
    BASELINE_TOTAL=0
    BASELINE_PASS=0
    BASELINE_WARN=0
    BASELINE_FAIL=0
    BASELINE_INFO=0
    BASELINE_SUGG=0

    BASELINE_CHECK_IDS=()
    BASELINE_STATUS=()
    BASELINE_TITLE=()
    BASELINE_CATEGORY=()
    BASELINE_DETAILS=()
    BASELINE_WEIGHT=()
    BASELINE_REMEDIATION=()

    DIFF_SCORE_DELTA="0.0"
    DIFF_SCORE_DELTA_FORMATTED="0.0%"
    DIFF_COUNT_REGRESSIONS=0
    DIFF_COUNT_FIXED=0
    DIFF_COUNT_UNCHANGED=0
    DIFF_JSON_DATA=""

    DIFF_REGRESSIONS_IDS=()
    DIFF_REGRESSIONS_CATEGORIES=()
    DIFF_REGRESSIONS_TITLES=()
    DIFF_REGRESSIONS_OLD=()
    DIFF_REGRESSIONS_NEW=()
    DIFF_REGRESSIONS_WEIGHTS=()
    DIFF_REGRESSIONS_DETAILS=()

    DIFF_FIXED_IDS=()
    DIFF_FIXED_CATEGORIES=()
    DIFF_FIXED_TITLES=()
    DIFF_FIXED_OLD=()
    DIFF_FIXED_NEW=()
    DIFF_FIXED_WEIGHTS=()
    DIFF_FIXED_DETAILS=()

    DIFF_UNCHANGED_IDS=()
    DIFF_UNCHANGED_TITLES=()
    DIFF_UNCHANGED_STATUS=()
}

# Check if baseline is currently loaded
diff_is_active() {
    [[ -n "$BASELINE_FILE" ]]
}

# ==============================================================================
# diff_load_baseline <baseline_json_path>
# Parses baseline JSON using python3 helper into associative arrays & metrics
# ==============================================================================
diff_load_baseline() {
    local baseline_path="${1:-}"

    if [[ -z "$baseline_path" ]]; then
        echo "Error: diff_load_baseline requires a baseline JSON file path" >&2
        return 1
    fi

    if [[ ! -f "$baseline_path" ]]; then
        echo "Error: Baseline file does not exist: $baseline_path" >&2
        return 1
    fi

    if [[ ! -r "$baseline_path" ]]; then
        echo "Error: Baseline file is not readable: $baseline_path" >&2
        return 1
    fi

    diff_reset
    BASELINE_FILE="$baseline_path"

    local parser_output
    parser_output=$(python3 -c '
import json, sys, os

filepath = sys.argv[1]
try:
    with open(filepath, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception as e:
    sys.stderr.write(f"Error: Failed to parse baseline JSON \"{filepath}\": {e}\n")
    sys.exit(1)

scanner = data.get("scanner", {})
sys_info = data.get("system", {})
summary = data.get("summary", {})
checks = data.get("checks", [])

ts = scanner.get("timestamp", "")
host = sys_info.get("hostname", "")
user = sys_info.get("user", "")
os_product = sys_info.get("os_product", "macOS")
os_ver = sys_info.get("os_version", "")
os_build = sys_info.get("os_build", "")
os_full = os_product
if os_ver:
    os_full += f" {os_ver}"
if os_build:
    os_full += f" ({os_build})"

score = summary.get("hardening_index", 0.0)
rating = summary.get("rating", "")
total = summary.get("total_checks", len(checks))
passed = summary.get("passed", 0)
warnings = summary.get("warnings", 0)
failed = summary.get("failed", 0)
info = summary.get("info", 0)
sugg = summary.get("suggestions", 0)

print(f"META\ttimestamp\t{ts}")
print(f"META\thostname\t{host}")
print(f"META\tuser\t{user}")
print(f"META\tos\t{os_full}")
print(f"META\tscore\t{score}")
print(f"META\trating\t{rating}")
print(f"META\ttotal\t{total}")
print(f"META\tpass\t{passed}")
print(f"META\twarn\t{warnings}")
print(f"META\tfail\t{failed}")
print(f"META\tinfo\t{info}")
print(f"META\tsugg\t{sugg}")

for c in checks:
    cid = c.get("id", "")
    cat = c.get("category", "")
    stat = c.get("status", "INFO")
    w = c.get("weight", 5)
    title = c.get("title", "")
    det = str(c.get("details", "")).replace("\n", "\\n").replace("\t", " ")
    rem = str(c.get("remediation", "")).replace("\n", "\\n").replace("\t", " ")
    print(f"CHECK\t{cid}\t{cat}\t{stat}\t{w}\t{title}\t{det}\t{rem}")
' "$baseline_path" 2>&1)

    local ret=$?
    if [[ $ret -ne 0 ]]; then
        echo "$parser_output" >&2
        return 1
    fi

    while IFS=$'\t' read -r rec_type k v w x y z; do
        if [[ "$rec_type" == "META" ]]; then
            case "$k" in
                timestamp) BASELINE_TIMESTAMP="$v" ;;
                hostname) BASELINE_HOSTNAME="$v" ;;
                user) BASELINE_USER="$v" ;;
                os) BASELINE_OS="$v" ;;
                score) BASELINE_SCORE="${v:-0.0}" ;;
                rating) BASELINE_RATING="$v" ;;
                total) BASELINE_TOTAL="${v:-0}" ;;
                pass) BASELINE_PASS="${v:-0}" ;;
                warn) BASELINE_WARN="${v:-0}" ;;
                fail) BASELINE_FAIL="${v:-0}" ;;
                info) BASELINE_INFO="${v:-0}" ;;
                sugg) BASELINE_SUGG="${v:-0}" ;;
            esac
        elif [[ "$rec_type" == "CHECK" ]]; then
            local cid="$k" ccat="$v" cstat="$w" cw="$x" ctitle="$y" cdet="$z"
            [[ -z "$cid" ]] && continue
            BASELINE_CHECK_IDS+=("$cid")
            BASELINE_CATEGORY[$cid]="$ccat"
            BASELINE_STATUS[$cid]="$cstat"
            BASELINE_WEIGHT[$cid]="$cw"
            BASELINE_TITLE[$cid]="$ctitle"
            BASELINE_DETAILS[$cid]="${cdet//\\n/$'\n'}"
        fi
    done <<< "$parser_output"

    return 0
}

# ==============================================================================
# diff_calculate
# Compares current audit results against baseline metrics:
# - Baseline Score vs Current Score (Delta: +/-X.X%)
# - New Regressions: baseline PASS/WARN -> current FAIL, or baseline PASS -> current WARN
# - Remediated Issues: baseline FAIL/WARN -> current PASS
# - Unchanged findings
# ==============================================================================
diff_calculate() {
    if [[ -z "$BASELINE_FILE" ]]; then
        echo "Error: No baseline loaded. Call diff_load_baseline first." >&2
        return 1
    fi

    # Reset diff findings
    DIFF_COUNT_REGRESSIONS=0
    DIFF_COUNT_FIXED=0
    DIFF_COUNT_UNCHANGED=0

    DIFF_REGRESSIONS_IDS=()
    DIFF_REGRESSIONS_CATEGORIES=()
    DIFF_REGRESSIONS_TITLES=()
    DIFF_REGRESSIONS_OLD=()
    DIFF_REGRESSIONS_NEW=()
    DIFF_REGRESSIONS_WEIGHTS=()
    DIFF_REGRESSIONS_DETAILS=()

    DIFF_FIXED_IDS=()
    DIFF_FIXED_CATEGORIES=()
    DIFF_FIXED_TITLES=()
    DIFF_FIXED_OLD=()
    DIFF_FIXED_NEW=()
    DIFF_FIXED_WEIGHTS=()
    DIFF_FIXED_DETAILS=()

    DIFF_UNCHANGED_IDS=()
    DIFF_UNCHANGED_TITLES=()
    DIFF_UNCHANGED_STATUS=()

    # Calculate Score Delta
    local delta_calc
    delta_calc=$(python3 -c '
import sys
cur = float(sys.argv[1])
base = float(sys.argv[2])
diff = cur - base
sign = "+" if diff > 0 else ""
print(f"{diff:.1f}\t{sign}{diff:.1f}%")
' "${HARDENING_INDEX:-0.0}" "${BASELINE_SCORE:-0.0}")
    DIFF_SCORE_DELTA="${delta_calc%%	*}"
    DIFF_SCORE_DELTA_FORMATTED="${delta_calc#*	}"

    # Iterate over current audit results
    local n=${#RES_IDS[@]}
    local i
    for (( i = 1; i <= n; i++ )); do
        local cid="${RES_IDS[i]}"
        local cur_stat="${RES_STATUSES[i]}"
        local cur_title="${RES_TITLES[i]}"
        local cur_det="${RES_DETAILS[i]}"
        local cur_cat="${RES_CATEGORIES[i]}"
        local cur_w="${RES_WEIGHTS[i]}"

        local base_stat="${BASELINE_STATUS[$cid]:-}"
        [[ -z "$base_stat" ]] && continue

        # 1. New Regressions:
        # Baseline PASS/WARN -> current FAIL
        # Baseline PASS -> current WARN
        if [[ ( ("$base_stat" == "PASS" || "$base_stat" == "WARN") && "$cur_stat" == "FAIL" ) || \
              ( "$base_stat" == "PASS" && "$cur_stat" == "WARN" ) ]]; then
            DIFF_REGRESSIONS_IDS+=("$cid")
            DIFF_REGRESSIONS_CATEGORIES+=("$cur_cat")
            DIFF_REGRESSIONS_TITLES+=("$cur_title")
            DIFF_REGRESSIONS_OLD+=("$base_stat")
            DIFF_REGRESSIONS_NEW+=("$cur_stat")
            DIFF_REGRESSIONS_WEIGHTS+=("$cur_w")
            DIFF_REGRESSIONS_DETAILS+=("$cur_det")
            (( ++DIFF_COUNT_REGRESSIONS ))

        # 2. Remediated Issues:
        # Baseline FAIL/WARN -> current PASS
        elif [[ ("$base_stat" == "FAIL" || "$base_stat" == "WARN") && "$cur_stat" == "PASS" ]]; then
            DIFF_FIXED_IDS+=("$cid")
            DIFF_FIXED_CATEGORIES+=("$cur_cat")
            DIFF_FIXED_TITLES+=("$cur_title")
            DIFF_FIXED_OLD+=("$base_stat")
            DIFF_FIXED_NEW+=("$cur_stat")
            DIFF_FIXED_WEIGHTS+=("$cur_w")
            DIFF_FIXED_DETAILS+=("$cur_det")
            (( ++DIFF_COUNT_FIXED ))

        # 3. Unchanged findings:
        elif [[ "$base_stat" == "$cur_stat" ]]; then
            DIFF_UNCHANGED_IDS+=("$cid")
            DIFF_UNCHANGED_TITLES+=("$cur_title")
            DIFF_UNCHANGED_STATUS+=("$cur_stat")
            (( ++DIFF_COUNT_UNCHANGED ))
        fi
    done

    # Generate cached diff JSON data
    DIFF_JSON_DATA=$(python3 -c '
import json, sys

base_file = sys.argv[1]
base_ts = sys.argv[2]
base_host = sys.argv[3]
base_user = sys.argv[4]
base_os = sys.argv[5]
base_score = float(sys.argv[6]) if sys.argv[6] else 0.0
base_rating = sys.argv[7]
base_tot = int(sys.argv[8]) if sys.argv[8] else 0
base_p = int(sys.argv[9]) if sys.argv[9] else 0
base_w = int(sys.argv[10]) if sys.argv[10] else 0
base_f = int(sys.argv[11]) if sys.argv[11] else 0
base_inf = int(sys.argv[12]) if sys.argv[12] else 0
base_sugg = int(sys.argv[13]) if sys.argv[13] else 0

cur_ts = sys.argv[14]
cur_host = sys.argv[15]
cur_user = sys.argv[16]
cur_os = sys.argv[17]
cur_score = float(sys.argv[18]) if sys.argv[18] else 0.0
cur_rating = sys.argv[19]
cur_tot = int(sys.argv[20]) if sys.argv[20] else 0
cur_p = int(sys.argv[21]) if sys.argv[21] else 0
cur_w = int(sys.argv[22]) if sys.argv[22] else 0
cur_f = int(sys.argv[23]) if sys.argv[23] else 0
cur_inf = int(sys.argv[24]) if sys.argv[24] else 0
cur_sugg = int(sys.argv[25]) if sys.argv[25] else 0

delta_score = float(sys.argv[26]) if sys.argv[26] else 0.0
delta_fmt = sys.argv[27]

idx = 28
num_reg = int(sys.argv[idx]); idx += 1
reg_ids = sys.argv[idx : idx + num_reg]; idx += num_reg
reg_cats = sys.argv[idx : idx + num_reg]; idx += num_reg
reg_titles = sys.argv[idx : idx + num_reg]; idx += num_reg
reg_olds = sys.argv[idx : idx + num_reg]; idx += num_reg
reg_news = sys.argv[idx : idx + num_reg]; idx += num_reg
reg_weights = sys.argv[idx : idx + num_reg]; idx += num_reg
reg_details = sys.argv[idx : idx + num_reg]; idx += num_reg

num_fix = int(sys.argv[idx]); idx += 1
fix_ids = sys.argv[idx : idx + num_fix]; idx += num_fix
fix_cats = sys.argv[idx : idx + num_fix]; idx += num_fix
fix_titles = sys.argv[idx : idx + num_fix]; idx += num_fix
fix_olds = sys.argv[idx : idx + num_fix]; idx += num_fix
fix_news = sys.argv[idx : idx + num_fix]; idx += num_fix
fix_weights = sys.argv[idx : idx + num_fix]; idx += num_fix
fix_details = sys.argv[idx : idx + num_fix]; idx += num_fix

num_unc = int(sys.argv[idx]); idx += 1
unc_ids = sys.argv[idx : idx + num_unc]; idx += num_unc
unc_titles = sys.argv[idx : idx + num_unc]; idx += num_unc
unc_stats = sys.argv[idx : idx + num_unc]; idx += num_unc

regressions = []
for j in range(num_reg):
    try:
        w = float(reg_weights[j]) if "." in reg_weights[j] else int(reg_weights[j])
    except Exception:
        w = 5
    regressions.append({
        "id": reg_ids[j],
        "category": reg_cats[j],
        "title": reg_titles[j],
        "baseline_status": reg_olds[j],
        "current_status": reg_news[j],
        "weight": w,
        "details": reg_details[j]
    })

remediated = []
for j in range(num_fix):
    try:
        w = float(fix_weights[j]) if "." in fix_weights[j] else int(fix_weights[j])
    except Exception:
        w = 5
    remediated.append({
        "id": fix_ids[j],
        "category": fix_cats[j],
        "title": fix_titles[j],
        "baseline_status": fix_olds[j],
        "current_status": fix_news[j],
        "weight": w,
        "details": fix_details[j]
    })

unchanged = []
for j in range(num_unc):
    unchanged.append({
        "id": unc_ids[j],
        "title": unc_titles[j],
        "status": unc_stats[j]
    })

diff_doc = {
    "baseline_file": base_file,
    "baseline": {
        "timestamp": base_ts,
        "hostname": base_host,
        "user": base_user,
        "os": base_os,
        "hardening_index": base_score,
        "rating": base_rating,
        "total_checks": base_tot,
        "passed": base_p,
        "warnings": base_w,
        "failed": base_f,
        "info": base_inf,
        "suggestions": base_sugg
    },
    "current": {
        "timestamp": cur_ts,
        "hostname": cur_host,
        "user": cur_user,
        "os": cur_os,
        "hardening_index": cur_score,
        "rating": cur_rating,
        "total_checks": cur_tot,
        "passed": cur_p,
        "warnings": cur_w,
        "failed": cur_f,
        "info": cur_inf,
        "suggestions": cur_sugg
    },
    "delta": {
        "score": delta_score,
        "score_formatted": delta_fmt,
        "has_regressions": num_reg > 0,
        "regressions_count": num_reg,
        "remediated_count": num_fix,
        "unchanged_count": num_unc
    },
    "regressions": regressions,
    "remediated": remediated,
    "unchanged": unchanged
}

print(json.dumps(diff_doc, indent=2))
' \
        "$BASELINE_FILE" \
        "$BASELINE_TIMESTAMP" \
        "$BASELINE_HOSTNAME" \
        "$BASELINE_USER" \
        "$BASELINE_OS" \
        "$BASELINE_SCORE" \
        "$BASELINE_RATING" \
        "$BASELINE_TOTAL" \
        "$BASELINE_PASS" \
        "$BASELINE_WARN" \
        "$BASELINE_FAIL" \
        "$BASELINE_INFO" \
        "$BASELINE_SUGG" \
        "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        "$(hostname -s 2>/dev/null || hostname)" \
        "$(id -un 2>/dev/null || whoami)" \
        "macOS $(sw_vers -productVersion 2>/dev/null || echo '')" \
        "${HARDENING_INDEX:-0.0}" \
        "$(_get_rating_text "${HARDENING_INDEX:-0.0}")" \
        "${COUNT_TOTAL:-0}" \
        "${COUNT_PASS:-0}" \
        "${COUNT_WARN:-0}" \
        "${COUNT_FAIL:-0}" \
        "${COUNT_INFO:-0}" \
        "${COUNT_SUGG:-0}" \
        "$DIFF_SCORE_DELTA" \
        "$DIFF_SCORE_DELTA_FORMATTED" \
        "${#DIFF_REGRESSIONS_IDS[@]}" \
        "${DIFF_REGRESSIONS_IDS[@]}" \
        "${DIFF_REGRESSIONS_CATEGORIES[@]}" \
        "${DIFF_REGRESSIONS_TITLES[@]}" \
        "${DIFF_REGRESSIONS_OLD[@]}" \
        "${DIFF_REGRESSIONS_NEW[@]}" \
        "${DIFF_REGRESSIONS_WEIGHTS[@]}" \
        "${DIFF_REGRESSIONS_DETAILS[@]}" \
        "${#DIFF_FIXED_IDS[@]}" \
        "${DIFF_FIXED_IDS[@]}" \
        "${DIFF_FIXED_CATEGORIES[@]}" \
        "${DIFF_FIXED_TITLES[@]}" \
        "${DIFF_FIXED_OLD[@]}" \
        "${DIFF_FIXED_NEW[@]}" \
        "${DIFF_FIXED_WEIGHTS[@]}" \
        "${DIFF_FIXED_DETAILS[@]}" \
        "${#DIFF_UNCHANGED_IDS[@]}" \
        "${DIFF_UNCHANGED_IDS[@]}" \
        "${DIFF_UNCHANGED_TITLES[@]}" \
        "${DIFF_UNCHANGED_STATUS[@]}"
    )

    return 0
}

# ==============================================================================
# diff_has_regressions
# Returns 0 if any new regressions are present, 1 otherwise
# ==============================================================================
diff_has_regressions() {
    if (( ${#DIFF_REGRESSIONS_IDS[@]} > 0 )); then
        return 0
    else
        return 1
    fi
}

# ==============================================================================
# diff_get_json
# Outputs diff summary JSON object for integration into report.json & HTML report
# ==============================================================================
diff_get_json() {
    if [[ -z "$DIFF_JSON_DATA" ]]; then
        if [[ -n "$BASELINE_FILE" ]]; then
            diff_calculate >/dev/null 2>&1
        fi
    fi
    if [[ -n "$DIFF_JSON_DATA" ]]; then
        printf "%s\n" "$DIFF_JSON_DATA"
    else
        echo "{}"
    fi
}

# Helper: Visual score delta progress bar
_render_diff_progress_bar() {
    local base_score="${1:-0}"
    local cur_score="${2:-0}"
    local width=30

    local b_int=0 c_int=0
    [[ "$base_score" =~ ^[0-9]+ ]] && b_int=${base_score%%.*}
    [[ "$cur_score" =~ ^[0-9]+ ]] && c_int=${cur_score%%.*}
    (( b_int < 0 )) && b_int=0; (( b_int > 100 )) && b_int=100
    (( c_int < 0 )) && c_int=0; (( c_int > 100 )) && c_int=100

    local b_fill=$(( (b_int * width) / 100 ))
    local c_fill=$(( (c_int * width) / 100 ))

    if (( c_fill >= b_fill )); then
        # Improved or equal
        local base_str="" gain_str="" unfilled_str=""
        local i
        for (( i = 0; i < b_fill; i++ )); do base_str="${base_str}█"; done
        for (( i = 0; i < (c_fill - b_fill); i++ )); do gain_str="${gain_str}▒"; done
        for (( i = 0; i < (width - c_fill); i++ )); do unfilled_str="${unfilled_str}░"; done
        printf "[${COLOR_BCYAN}%s${COLOR_RESET}${COLOR_BGREEN}%s${COLOR_RESET}${COLOR_DIM}%s${COLOR_RESET}]" \
            "$base_str" "$gain_str" "$unfilled_str"
    else
        # Regressed
        local cur_str="" loss_str="" unfilled_str=""
        local i
        for (( i = 0; i < c_fill; i++ )); do cur_str="${cur_str}█"; done
        for (( i = 0; i < (b_fill - c_fill); i++ )); do loss_str="${loss_str}▓"; done
        for (( i = 0; i < (width - b_fill); i++ )); do unfilled_str="${unfilled_str}░"; done
        printf "[${COLOR_BCYAN}%s${COLOR_RESET}${COLOR_BRED}%s${COLOR_RESET}${COLOR_DIM}%s${COLOR_RESET}]" \
            "$cur_str" "$loss_str" "$unfilled_str"
    fi
}

# Helper: Visual score row
_render_diff_score_row() {
    local label="$1"
    local score="${2:-0}"
    local rating_str="$3"
    local int_score=0
    [[ "$score" =~ ^[0-9]+ ]] && int_score=${score%%.*}
    (( int_score < 0 )) && int_score=0
    (( int_score > 100 )) && int_score=100

    local bar_width=30
    local filled=$(( (int_score * bar_width) / 100 ))
    local unfilled=$(( bar_width - filled ))
    local bar_color="${COLOR_BRED}"
    local rating_color="${COLOR_BRED}"

    if (( int_score >= 85 )); then
        bar_color="${COLOR_BGREEN}"
        rating_color="${COLOR_BGREEN}"
    elif (( int_score >= 70 )); then
        bar_color="${COLOR_BYELLOW}"
        rating_color="${COLOR_BYELLOW}"
    elif (( int_score >= 50 )); then
        bar_color="${COLOR_YELLOW}"
        rating_color="${COLOR_YELLOW}"
    else
        bar_color="${COLOR_BRED}"
        rating_color="${COLOR_BRED}"
    fi

    local filled_str="" unfilled_str=""
    local i
    for (( i = 0; i < filled; i++ )); do filled_str="${filled_str}█"; done
    for (( i = 0; i < unfilled; i++ )); do unfilled_str="${unfilled_str}░"; done

    printf "  ${COLOR_BOLD}%-18s${COLOR_RESET} [${bar_color}%s${COLOR_RESET}${COLOR_DIM}%s${COLOR_RESET}] ${COLOR_BOLD}%5.1f%%${COLOR_RESET} (${rating_color}%s${COLOR_RESET})\n" \
        "$label" "$filled_str" "$unfilled_str" "$score" "$rating_str"
}

# ==============================================================================
# diff_report_terminal
# Displays a clean ASCII diff summary:
# - Baseline Date & Hostname vs Current
# - Score Delta Progress Bar
# - Highlighting New Regressions (in Red) and Fixed Issues (in Green)
# ==============================================================================
diff_report_terminal() {
    local is_tr=0
    [[ "${CURRENT_LANG:-en}" == "tr" ]] && is_tr=1

    echo ""
    echo "${COLOR_BOLD}${COLOR_BCYAN}======================================================================${COLOR_RESET}"
    if (( is_tr )); then
        echo "                     ${COLOR_BOLD}TEMEL ÇİZGİ SAPMA VE GÜVENLİK FARKI${COLOR_RESET}"
    else
        echo "                     ${COLOR_BOLD}BASELINE DRIFT & SECURITY DIFF${COLOR_RESET}"
    fi
    echo "${COLOR_BOLD}${COLOR_BCYAN}======================================================================${COLOR_RESET}"
    echo ""

    local cur_time
    cur_time=$(date "+%Y-%m-%d %H:%M:%S %Z")
    local cur_host
    cur_host=$(hostname -s 2>/dev/null || hostname)

    local b_ts="${BASELINE_TIMESTAMP:-Unknown}"
    local b_host="${BASELINE_HOSTNAME:-Unknown}"

    if (( is_tr )); then
        printf "  ${COLOR_BOLD}%-18s${COLOR_RESET} %s (${COLOR_DIM}Hedef: %s${COLOR_RESET})\n" "Temel Çizgi:" "$b_ts" "$b_host"
        printf "  ${COLOR_BOLD}%-18s${COLOR_RESET} %s (${COLOR_DIM}Hedef: %s${COLOR_RESET})\n" "Geçerli Denetim:" "$cur_time" "$cur_host"
    else
        printf "  ${COLOR_BOLD}%-18s${COLOR_RESET} %s (${COLOR_DIM}Host: %s${COLOR_RESET})\n" "Baseline Scan:" "$b_ts" "$b_host"
        printf "  ${COLOR_BOLD}%-18s${COLOR_RESET} %s (${COLOR_DIM}Host: %s${COLOR_RESET})\n" "Current Scan:" "$cur_time" "$cur_host"
    fi
    echo "${COLOR_DIM}----------------------------------------------------------------------${COLOR_RESET}"

    # Score comparison rows
    local base_rating cur_rating
    base_rating="${BASELINE_RATING:-$(_get_rating_text "$BASELINE_SCORE")}"
    cur_rating="$(_get_rating_text "$HARDENING_INDEX")"

    if (( is_tr )); then
        _render_diff_score_row "Temel Skor:" "$BASELINE_SCORE" "$base_rating"
        _render_diff_score_row "Geçerli Skor:" "$HARDENING_INDEX" "$cur_rating"
    else
        _render_diff_score_row "Baseline Score:" "$BASELINE_SCORE" "$base_rating"
        _render_diff_score_row "Current Score:" "$HARDENING_INDEX" "$cur_rating"
    fi

    # Delta badge & Drift bar
    local delta_num=0.0
    [[ "$DIFF_SCORE_DELTA" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] && delta_num="$DIFF_SCORE_DELTA"

    local delta_badge=""
    if (( delta_num > 0.0001 )); then
        if (( is_tr )); then
            delta_badge="${COLOR_BGREEN}${DIFF_SCORE_DELTA_FORMATTED} [▲ İYİLEŞME]${COLOR_RESET}"
        else
            delta_badge="${COLOR_BGREEN}${DIFF_SCORE_DELTA_FORMATTED} [▲ IMPROVED]${COLOR_RESET}"
        fi
    elif (( delta_num < -0.0001 )); then
        if (( is_tr )); then
            delta_badge="${COLOR_BRED}${DIFF_SCORE_DELTA_FORMATTED} [▼ GERİLEME]${COLOR_RESET}"
        else
            delta_badge="${COLOR_BRED}${DIFF_SCORE_DELTA_FORMATTED} [▼ REGRESSED]${COLOR_RESET}"
        fi
    else
        if (( is_tr )); then
            delta_badge="${COLOR_BCYAN}${DIFF_SCORE_DELTA_FORMATTED} [◼ DEĞİŞİMSİZ]${COLOR_RESET}"
        else
            delta_badge="${COLOR_BCYAN}${DIFF_SCORE_DELTA_FORMATTED} [◼ NO DRIFT]${COLOR_RESET}"
        fi
    fi

    local diff_bar
    diff_bar=$(_render_diff_progress_bar "$BASELINE_SCORE" "$HARDENING_INDEX")
    if (( is_tr )); then
        printf "  ${COLOR_BOLD}%-20s${COLOR_RESET} %s  %b\n" "Skor Sapması:" "$diff_bar" "$delta_badge"
    else
        printf "  ${COLOR_BOLD}%-20s${COLOR_RESET} %s  %b\n" "Score Drift:" "$diff_bar" "$delta_badge"
    fi

    echo "${COLOR_DIM}----------------------------------------------------------------------${COLOR_RESET}"

    # Counts summary
    local reg_color="${COLOR_DIM}"
    (( DIFF_COUNT_REGRESSIONS > 0 )) && reg_color="${COLOR_BRED}"

    local fix_color="${COLOR_DIM}"
    (( DIFF_COUNT_FIXED > 0 )) && fix_color="${COLOR_BGREEN}"

    if (( is_tr )); then
        echo "  ${COLOR_BOLD}Sapma Özeti:${COLOR_RESET}"
        printf "    • Yeni Gerilemeler  : %b%d%b\n" "$reg_color" "$DIFF_COUNT_REGRESSIONS" "${COLOR_RESET}"
        printf "    • İyileştirilenler  : %b%d%b\n" "$fix_color" "$DIFF_COUNT_FIXED" "${COLOR_RESET}"
        printf "    • Değişmeyenler     : %d\n" "$DIFF_COUNT_UNCHANGED"
    else
        echo "  ${COLOR_BOLD}Drift Summary:${COLOR_RESET}"
        printf "    • New Regressions : %b%d%b\n" "$reg_color" "$DIFF_COUNT_REGRESSIONS" "${COLOR_RESET}"
        printf "    • Fixed / Healed  : %b%d%b\n" "$fix_color" "$DIFF_COUNT_FIXED" "${COLOR_RESET}"
        printf "    • Unchanged       : %d\n" "$DIFF_COUNT_UNCHANGED"
    fi

    # Detailed Regressions (in Red)
    if (( DIFF_COUNT_REGRESSIONS > 0 )); then
        echo ""
        if (( is_tr )); then
            echo "  ${COLOR_BOLD}${COLOR_BRED}▶ Yeni Güvenlik Gerilemeleri (${DIFF_COUNT_REGRESSIONS}):${COLOR_RESET}"
        else
            echo "  ${COLOR_BOLD}${COLOR_BRED}▶ New Security Regressions (${DIFF_COUNT_REGRESSIONS}):${COLOR_RESET}"
        fi
        echo "  ${COLOR_DIM}--------------------------------------------------------------------${COLOR_RESET}"
        local k
        for (( k = 1; k <= DIFF_COUNT_REGRESSIONS; k++ )); do
            local rid="${DIFF_REGRESSIONS_IDS[k]}"
            local rtitle="${DIFF_REGRESSIONS_TITLES[k]}"
            local rold="${DIFF_REGRESSIONS_OLD[k]}"
            local rnew="${DIFF_REGRESSIONS_NEW[k]}"
            local rcat="${DIFF_REGRESSIONS_CATEGORIES[k]}"
            local rw="${DIFF_REGRESSIONS_WEIGHTS[k]}"
            local rdet="${DIFF_REGRESSIONS_DETAILS[k]}"

            printf "    ${COLOR_BRED}[REGRESSION]${COLOR_RESET} ${COLOR_BOLD}%-10s${COLOR_RESET} %s\n" "$rid" "$rtitle"
            printf "                 ${COLOR_DIM}↳ Posture :${COLOR_RESET} %b%s%b ➔ %b%s%b  (${COLOR_DIM}Category: %s, Weight: %s${COLOR_RESET})\n" \
                "${COLOR_BYELLOW}" "$rold" "${COLOR_RESET}" \
                "${COLOR_BRED}" "$rnew" "${COLOR_RESET}" \
                "$rcat" "$rw"
            if [[ -n "$rdet" ]]; then
                echo "$rdet" | while IFS= read -r dline; do
                    [[ -n "$dline" ]] && printf "                 ${COLOR_DIM}↳ Details : %s${COLOR_RESET}\n" "$dline"
                done
            fi
        done
    fi

    # Detailed Remediated / Fixed (in Green)
    if (( DIFF_COUNT_FIXED > 0 )); then
        echo ""
        if (( is_tr )); then
            echo "  ${COLOR_BOLD}${COLOR_BGREEN}▶ İyileştirilen Güvenlik Kontrolleri (${DIFF_COUNT_FIXED}):${COLOR_RESET}"
        else
            echo "  ${COLOR_BOLD}${COLOR_BGREEN}▶ Remediated Security Controls (${DIFF_COUNT_FIXED}):${COLOR_RESET}"
        fi
        echo "  ${COLOR_DIM}--------------------------------------------------------------------${COLOR_RESET}"
        local m
        for (( m = 1; m <= DIFF_COUNT_FIXED; m++ )); do
            local fid="${DIFF_FIXED_IDS[m]}"
            local ftitle="${DIFF_FIXED_TITLES[m]}"
            local fold="${DIFF_FIXED_OLD[m]}"
            local fnew="${DIFF_FIXED_NEW[m]}"
            local fcat="${DIFF_FIXED_CATEGORIES[m]}"
            local fw="${DIFF_FIXED_WEIGHTS[m]}"
            local fdet="${DIFF_FIXED_DETAILS[m]}"

            printf "    ${COLOR_BGREEN}[REMEDIATED]${COLOR_RESET} ${COLOR_BOLD}%-10s${COLOR_RESET} %s\n" "$fid" "$ftitle"
            printf "                 ${COLOR_DIM}↳ Posture :${COLOR_RESET} %b%s%b ➔ %b%s%b  (${COLOR_DIM}Category: %s, Weight: %s${COLOR_RESET})\n" \
                "${COLOR_BRED}" "$fold" "${COLOR_RESET}" \
                "${COLOR_BGREEN}" "$fnew" "${COLOR_RESET}" \
                "$fcat" "$fw"
            if [[ -n "$fdet" ]]; then
                echo "$fdet" | while IFS= read -r dline; do
                    [[ -n "$dline" ]] && printf "                 ${COLOR_DIM}↳ Details : %s${COLOR_RESET}\n" "$dline"
                done
            fi
        done
    fi

    if (( DIFF_COUNT_REGRESSIONS == 0 )); then
        echo ""
        if (( is_tr )); then
            echo "  ${COLOR_BGREEN}✔ Temel çizgiye göre herhangi bir güvenlik gerilemesi tespit edilmedi.${COLOR_RESET}"
        else
            echo "  ${COLOR_BGREEN}✔ No security regressions detected against baseline.${COLOR_RESET}"
        fi
    fi
    echo ""
}
