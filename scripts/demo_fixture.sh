#!/bin/zsh
# Deterministic, privacy-safe data source for the README demo, screenshots and tests.
#
# Every audit result below is synthetic and the script never inspects the host. The check
# list, titles and weights come from the real registry (lib/audit_*.sh) and the output is
# produced by the real renderers (terminal, HTML, drift), so what you see is what macharden
# prints for the same data.
#
# Usage:
#   demo_fixture.sh                      terminal audit, like `macharden`
#   demo_fixture.sh -f html [-o FILE]    HTML dashboard (default FILE: report.html)
#   demo_fixture.sh --diff               baseline drift report, like `macharden --diff`
#   demo_fixture.sh html FILE            HTML dashboard to FILE (used by scripts/generate_demo_gif.py)
#
# MACHAR_DEMO_DELAY=<seconds> pauses after each check so that recordings look live.

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"
LIB_DIR="${PROJECT_ROOT}/lib"

export MACHAR_HOSTNAME="demo-mac"
export MACHAR_USER="audit-demo"
export MACHAR_OS_PRODUCT="macOS"
export MACHAR_OS_VERSION="26.0"
export MACHAR_OS_BUILD="25A354"
export MACHAR_ARCH="arm64"
export MACHAR_KERNEL_RELEASE="25.0.0"
export MACHAR_AUDIT_TIME="2026-09-01 10:00:00 UTC"
export MACHAR_AUDIT_TIME_ISO="2026-09-01T10:00:00Z"
export MACHAR_TERM_WIDTH="92"

source "${LIB_DIR}/ui.sh"
source "${LIB_DIR}/engine.sh"
source "${LIB_DIR}/report.sh"
source "${LIB_DIR}/compliance.sh"
source "${LIB_DIR}/diff.sh"
source "${LIB_DIR}/report_html.sh"
for audit_file in "${LIB_DIR}"/audit_*.sh; do
    source "$audit_file"
done
ui_ensure_utf8_locale

# --- Synthetic outcomes ---------------------------------------------------------------
# Every check that is not listed in DEMO_STATUS passes. IDs, titles and weights come from
# the real registry, so the demo can never drift from the tool.
typeset -A DEMO_STATUS DEMO_OK_DETAIL DEMO_FINDING_DETAIL DEMO_FIX
DEMO_STATUS=(
    NET-10 FAIL   PERS-06 FAIL
    HARD-10 WARN  HARD-18 WARN  NET-04 WARN  NET-09 WARN  PERS-03 WARN  PERS-09 WARN
    SEC-03 SUGG   SEC-11 INFO
)
# Detail text when the check passes (generic text is used for checks that are not listed)
DEMO_OK_DETAIL=(
    HARD-01 "SIP is enabled and enforcing kernel and filesystem restrictions."
    HARD-02 "FileVault protects the startup and data volumes at rest."
    HARD-03 "Gatekeeper is active and enforcing signed, notarized software."
    HARD-18 "The OpenBSM audit policy matches the organization baseline."
    NET-01  "The application firewall is enabled."
    NET-02  "Stealth mode is on; ICMP probes are not answered."
    NET-10  "IPv4 forwarding is disabled."
    SEC-01  "No hardcoded API tokens found in ~/.zshrc or ~/.bashrc."
    SEC-07  "No API keys or bearer tokens found in shell history."
    PERS-01 "All LaunchAgent plists and target binaries have valid signatures."
    PERS-03 "The crontab contains only reviewed entries."
    PERS-05 "No unexpected entries in authorized_keys."
    PERS-06 "No NOPASSWD entries in sudoers."
)
# Detail text when the check does not pass
DEMO_FINDING_DETAIL=(
    HARD-10 "Automatic login is configured for a local account."
    HARD-18 "The OpenBSM audit policy differs from the organization baseline."
    NET-04  "/dev/bpf* is readable by an additional group."
    NET-09  "Application firewall logging is turned off."
    NET-10  "IPv4 forwarding is enabled (net.inet.ip.forwarding=1)."
    SEC-01  "A plaintext API token was found in ~/.zshrc."
    SEC-03  "No organization-defined Keychain lock timeout is selected in this demo profile."
    SEC-11  "Cloud credential files were inventoried for analyst review."
    PERS-03 "An unreviewed cron entry exists for the current user."
    PERS-06 "A NOPASSWD directive is present in /etc/sudoers.d/demo."
    PERS-09 "The sudo ticket timeout is longer than the baseline allows."
)
DEMO_FIX=(
    HARD-10 "[EXEC] sudo sysadminctl -autologin off"
    HARD-18 "[GUIDE] Review the approved OpenBSM profile before applying changes."
    NET-04  "[GUIDE] Restrict BPF devices to root and the access_bpf group."
    NET-09  "[EXEC] sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setloggingmode on"
    NET-10  "[EXEC] sudo sysctl -w net.inet.ip.forwarding=0"
    SEC-01  "[GUIDE] Move the token to the Keychain or a secrets manager and rotate it."
    PERS-03 "[GUIDE] Review the crontab and remove entries you do not recognize."
    PERS-06 "[GUIDE] Review the entry with visudo and remove it unless it is required."
    PERS-09 "[GUIDE] Set Defaults timestamp_timeout in a sudoers.d drop-in after review."
)

demo_pause() {
    local delay="${MACHAR_DEMO_DELAY:-0}"
    [[ "$delay" == "0" ]] || sleep "$delay"
    return 0
}

demo_reset_results() {
    RES_IDS=(); RES_CATEGORIES=(); RES_TITLES=(); RES_STATUSES=(); RES_WEIGHTS=()
    RES_DETAILS=(); RES_REMEDIATIONS=(); RES_DURATIONS=()
    COUNT_PASS=0; COUNT_WARN=0; COUNT_FAIL=0; COUNT_INFO=0; COUNT_SUGG=0; COUNT_TOTAL=0
}

# Record every registered check with its synthetic outcome. With "stream", section headers
# are printed and each result appears as it is recorded, like a live scan.
demo_record_all() {
    local stream="${1:-quiet}" i id category title weight state detail fix section=""
    for (( i = 1; i <= ${#REG_IDS[@]}; i++ )); do
        id="${REG_IDS[i]}"
        category="${REG_CATEGORIES[i]}"
        title="${REG_TITLES[i]}"
        weight="${REG_WEIGHTS[i]}"
        state="${DEMO_STATUS[$id]:-PASS}"
        if [[ "$state" == "PASS" ]]; then
            detail="${DEMO_OK_DETAIL[$id]:-Matches the demonstration baseline.}"
            fix=""
        else
            detail="${DEMO_FINDING_DETAIL[$id]:-Differs from the demonstration baseline.}"
            fix="${DEMO_FIX[$id]:-}"
        fi
        if [[ "$stream" == "stream" && "$category" != "$section" ]]; then
            section="$category"
            ui_section "${(C)category} Audit Checks"
        fi
        record_result "$id" "$category" "$title" "$state" "$weight" "$detail" "$fix"
        if [[ "$stream" == "stream" ]]; then demo_pause; fi
    done
}

demo_terminal() {
    export MACHAR_FORMAT="term" MACHAR_QUIET=0
    demo_reset_results
    ui_banner
    demo_record_all stream
    calculate_hardening_index
    report_terminal
}

demo_html() {
    local output_file="$1"
    export MACHAR_FORMAT="html" MACHAR_QUIET=0
    demo_reset_results
    demo_record_all quiet
    calculate_hardening_index
    report_html "$output_file" "en"
}

# Drift report: the baseline is the same data set as it looked two weeks earlier, written
# by the real JSON report and compared by the real diff engine.
demo_diff() {
    export MACHAR_FORMAT="term" MACHAR_QUIET=1
    local baseline
    baseline="$(mktemp "${TMPDIR:-/tmp}/macharden-demo-baseline.XXXXXX")"

    local -A current_status=("${(@kv)DEMO_STATUS}")
    DEMO_STATUS[NET-10]=PASS      # regressed since the baseline
    DEMO_STATUS[PERS-06]=PASS     # regressed since the baseline
    DEMO_STATUS[PERS-03]=PASS     # regressed since the baseline
    DEMO_STATUS[HARD-18]=PASS     # regressed since the baseline
    DEMO_STATUS[SEC-01]=FAIL      # remediated since the baseline
    demo_reset_results
    demo_record_all quiet
    calculate_hardening_index
    report_json "$baseline" >/dev/null

    DEMO_STATUS=("${(@kv)current_status}")
    export MACHAR_AUDIT_TIME="2026-09-15 14:00:00 UTC" MACHAR_AUDIT_TIME_ISO="2026-09-15T14:00:00Z"
    demo_reset_results
    demo_record_all quiet
    calculate_hardening_index
    diff_load_baseline "$baseline" >/dev/null
    diff_calculate >/dev/null
    rm -f "$baseline"
    diff_report_terminal
}

# --- Command line -----------------------------------------------------------------------
mode="term"; fmt="term"; out=""
if [[ "${1:-}" == "html" ]]; then
    (( $# >= 2 )) || { print -u2 "Usage: ${0:t} html <output-file>"; exit 2; }
    mode="html"; out="$2"; shift 2
fi
while (( $# > 0 )); do
    case "$1" in
        -f|--format) (( $# >= 2 )) || { print -u2 "${0:t}: $1 needs a value"; exit 2; }; fmt="$2"; shift ;;
        -o|--output) (( $# >= 2 )) || { print -u2 "${0:t}: $1 needs a value"; exit 2; }; out="$2"; shift ;;
        --diff) mode="diff" ;;
        *) print -u2 "${0:t}: unsupported argument: $1"; exit 2 ;;
    esac
    shift
done
if [[ "$mode" == "term" && "$fmt" == "html" ]]; then mode="html"; fi
if [[ "$mode" == "term" && "$fmt" != "term" ]]; then
    print -u2 "${0:t}: unsupported format: $fmt"; exit 2
fi

case "$mode" in
    html) demo_html "${out:-report.html}" ;;
    diff) demo_diff ;;
    *)    demo_terminal ;;
esac
