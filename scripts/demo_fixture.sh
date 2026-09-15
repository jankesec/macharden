#!/bin/zsh
# Deterministic, privacy-safe data source for README screenshots and recordings.
# This script never inspects the host. It renders synthetic audit results only.

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

demo_reset_results() {
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
}

demo_pause() {
    if [[ "${MACHAR_DEMO_DELAY:-0}" == "1" ]]; then
        sleep 0.12
    fi
}

demo_terminal() {
    export MACHAR_FORMAT="term"
    export MACHAR_QUIET=0
    demo_reset_results

    ui_banner
    ui_section "Hardening Audit Checks"
    record_result "HARD-01" "hardening" "System Integrity Protection (SIP)" "PASS" 10 \
        "SIP is enabled and enforcing kernel and filesystem restrictions." ""
    demo_pause
    record_result "HARD-02" "hardening" "FileVault Full Disk Encryption" "PASS" 10 \
        "FileVault protects the startup and data volumes at rest." ""
    demo_pause
    record_result "HARD-04" "hardening" "Gatekeeper Notarization & App Evaluation" "PASS" 9 \
        "Gatekeeper is active and enforcing signed developer notarization." ""
    demo_pause
    record_result "HARD-18" "hardening" "OpenBSM Audit Daemon & Trail Immutability" "WARN" 8 \
        "The demo baseline requires review of the audit daemon policy." \
        "[GUIDE] Review the organization-approved OpenBSM profile before applying changes."
    demo_pause

    ui_section "Network Audit Checks"
    record_result "NET-01" "network" "Application Firewall Status" "PASS" 8 \
        "The application firewall is enabled in block-all incoming mode." ""
    demo_pause
    record_result "NET-02" "network" "Firewall Stealth Mode" "PASS" 6 \
        "Stealth mode prevents response to ICMP ping queries." ""
    demo_pause
    record_result "NET-10" "network" "IPv4 Forwarding Routing Flag" "FAIL" 7 \
        "The synthetic demo host is configured to forward IPv4 traffic." \
        "[EXEC] sudo sysctl -w net.inet.ip.forwarding=0"
    demo_pause
    record_result "NET-11" "network" "BPF Packet Sniffing Access Permissions" "PASS" 8 \
        "/dev/bpf access restricted to root and access_bpf group." ""
    demo_pause

    ui_section "Secrets Audit Checks"
    record_result "SEC-01" "secrets" "Plaintext Secrets in Shell Profiles" "PASS" 9 \
        "No hardcoded API tokens or credentials found in ~/.zshrc or ~/.bashrc." ""
    demo_pause
    record_result "SEC-03" "secrets" "Keychain Auto-Lock Inactivity Policy" "SUGG" 5 \
        "No organization-defined lock timeout is selected in this demo profile." ""
    demo_pause
    record_result "SEC-07" "secrets" "Plaintext Secrets in Shell History" "PASS" 8 \
        "Zero API keys, private tokens or bearer strings found in shell history." ""
    demo_pause
    record_result "SEC-11" "secrets" "Cloud & Container Credentials Permissions" "PASS" 8 \
        "Permissions on ~/.aws, ~/.kube, and ~/.docker securely restricted." ""
    demo_pause

    ui_section "Persistence Audit Checks"
    record_result "PERS-01" "persistence" "User & System LaunchAgents Integrity" "PASS" 7 \
        "All LaunchAgent plists and target binaries match valid code signatures." ""
    demo_pause
    record_result "PERS-03" "persistence" "Scheduled Cron Jobs Inspection" "WARN" 6 \
        "Synthetic finding: unapproved cron entry detected in demo crontab." \
        "[GUIDE] Review and prune unapproved periodic cron triggers."
    demo_pause
    record_result "PERS-05" "persistence" "SSH authorized_keys Backdoor Audit" "PASS" 7 \
        "All authorized_keys files strictly hardened with no unauthorized keys." ""
    demo_pause
    record_result "PERS-06" "persistence" "Sudoers NOPASSWD Privilege Escalation" "FAIL" 8 \
        "Synthetic finding: NOPASSWD directive present in /etc/sudoers.d/demo." \
        "[EXEC] sudo visudo -f /etc/sudoers.d/demo"
    demo_pause

    calculate_hardening_index
    report_terminal
}

demo_html() {
    local output_file="$1"
    export MACHAR_FORMAT="html"
    export MACHAR_QUIET=1

    for audit_file in "${LIB_DIR}"/audit_*.sh; do
        source "$audit_file"
    done

    demo_reset_results
    local i id category title weight check_status details remediation
    for (( i = 1; i <= ${#REG_IDS[@]}; i++ )); do
        id="${REG_IDS[i]}"
        category="${REG_CATEGORIES[i]}"
        title="${REG_TITLES[i]}"
        weight="${REG_WEIGHTS[i]}"
        check_status="PASS"
        details="Control matches the synthetic demonstration baseline."
        remediation=""

        case "$id" in
            NET-10)
                check_status="FAIL"
                details="Synthetic finding: IPv4 forwarding is enabled on the demonstration host."
                remediation="[EXEC] sudo sysctl -w net.inet.ip.forwarding=0"
                ;;
            PERS-03)
                check_status="FAIL"
                details="Synthetic finding: an unapproved demonstration cron entry requires review."
                remediation="[GUIDE] Review and remove the unapproved demo cron entry."
                ;;
            HARD-10|HARD-18|NET-04|SEC-07|PERS-06|PERS-09)
                check_status="WARN"
                details="Synthetic warning: this control differs from the demonstration baseline."
                remediation="[GUIDE] Validate the organization policy before changing this control."
                ;;
            SEC-03)
                check_status="SUGG"
                details="No organization-defined Keychain timeout is selected in the demo profile."
                ;;
            SEC-11)
                check_status="INFO"
                details="Synthetic inventory result recorded for analyst review."
                ;;
        esac

        record_result "$id" "$category" "$title" "$check_status" "$weight" "$details" "$remediation"
    done

    calculate_hardening_index
    report_html "$output_file" "en"
}

demo_diff() {
    print "\033[1;36m======================================================================\033[0m"
    print "\033[1;37m                  BASELINE DRIFT & SECURITY DIFF                      \033[0m"
    print "\033[1;36m======================================================================\033[0m"
    print "  Baseline Scan : 2026-09-01 10:00:00 UTC (Host: demo-mac)"
    print "  Current Scan  : 2026-09-15 14:00:00 UTC (Host: demo-mac)"
    print "  Baseline Score: 87.5% (A-)"
    print "  Current Score : 81.5% (B+)"
    print "  Score Drift   : \033[1;33m-6.0% [▼ POSTURE DRIFT DETECTED]\033[0m\n"
    print "  Regressions   : 2 new failing/warning check(s)"
    print "  Remediations  : 1 previously failed check(s) resolved\n"
    print "\033[1;31m▶ Security Regressions (Action Required):\033[0m"
    print "  \033[1;31m[✖ FAIL]\033[0m  PERS-06  Sudoers NOPASSWD Privilege Escalation (was PASS)"
    print "  \033[1;33m[▲ WARN]\033[0m  PERS-03  Scheduled Cron Jobs Inspection (was PASS)\n"
    print "\033[1;32m▶ Remediated Checks (Resolved):\033[0m"
    print "  \033[1;32m[✔ PASS]\033[0m  SEC-01   Plaintext Secrets in Shell Profiles (was FAIL)"
}

demo_html_cli() {
    local outfile="${1:-report.html}"
    print "\033[1;36m╭──────────────────────────────────────────────────────────────────────────────────────────╮\033[0m"
    print "\033[1;36m│\033[0m  \033[1;37mMACHARDEN / macOS Security Posture / v1.4.0\033[0m                                             \033[1;36m│\033[0m"
    print "\033[1;36m╰──────────────────────────────────────────────────────────────────────────────────────────╯\033[0m\n"
    print "  \033[1;32m[✔]\033[0m 54 enterprise security controls audited in \033[1m48ms\033[0m"
    print "  \033[1;32m[✔]\033[0m Liquid Glass HTML5 security dashboard written to: \033[1;34m${outfile}\033[0m"
    print "  \033[1;32m[✔]\033[0m Standalone single-file (486 KB) • Zero external CDN dependencies • 100% Air-Gapped"
    print "  \033[1;32m[✔]\033[0m Bilingual (English ⇄ Turkish) • Dark Glass & Light Modes • Playbook Drawer"
}

if [[ "$*" == *"--diff"* ]]; then
    demo_diff
elif [[ "$*" == *"-f html"* || "$*" == *"--format html"* || "$*" == *"report.html"* ]]; then
    demo_html_cli "report.html"
elif [[ "${1:-}" == "html" ]]; then
    [[ $# -ge 2 ]] || { print -u2 "Usage: $0 html <output-file>"; exit 2; }
    demo_html "$2"
else
    demo_terminal
fi

