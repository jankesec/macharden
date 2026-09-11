#!/bin/zsh
# ==============================================================================
# macharden - lib/remediate.sh
# Remediation generator and interactive remediation runner
# ==============================================================================

# Ensure color and UI helpers exist even if ui.sh was not pre-sourced
if ! typeset -f ui_result >/dev/null 2>&1; then
    ui_success() { printf "\033[92m[PASS]\033[0m %s\n" "$1"; }
    ui_warn()    { printf "\033[93m[WARN]\033[0m %s\n" "$1"; }
    ui_error()   { printf "\033[91m[ERROR]\033[0m %s\n" "$1" >&2; }
    ui_info()    { printf "\033[96m[INFO]\033[0m %s\n" "$1"; }
fi

# ==============================================================================
# Generate a standalone, executable remediation shell script
# Usage: generate_fix_script [output_file]
# ==============================================================================
generate_fix_script() {
    local output_file="${1:-fix_hardening.sh}"
    if [[ -z "$output_file" ]]; then
        output_file="fix_hardening.sh"
    fi

    local n=${#RES_IDS[@]}
    local fixable_indices=()

    # Count applicable remediations
    for (( i = 1; i <= n; i++ )); do
        local st="${RES_STATUSES[i]}"
        local rem="${RES_REMEDIATIONS[i]}"
        if [[ ( "$st" == "FAIL" || "$st" == "WARN" ) && -n "$rem" ]]; then
            fixable_indices+=("$i")
        fi
    done

    local total_fixes=${#fixable_indices[@]}

    # Ensure target directory exists
    local out_dir
    out_dir=$(dirname "$output_file" 2>/dev/null || echo ".")
    [[ -d "$out_dir" ]] || mkdir -p "$out_dir"

    local hostname user current_time os_product os_version os_build arch
    hostname=$(hostname -s 2>/dev/null || hostname)
    user=$(id -un 2>/dev/null || whoami)
    current_time=$(date "+%Y-%m-%d %H:%M:%S %Z")
    os_product=$(sw_vers -productName 2>/dev/null || echo "macOS")
    os_version=$(sw_vers -productVersion 2>/dev/null || echo "Unknown")
    os_build=$(sw_vers -buildVersion 2>/dev/null || echo "Unknown")
    arch=$(uname -m 2>/dev/null || echo "arm64")

    # Generate standalone fix script
    cat <<'EOF' > "$output_file"
#!/bin/bash
# ==============================================================================
# macharden - Automated Security Hardening Fix Script
# ==============================================================================
# This script applies recommended security hardening remediations identified
# by the macharden security scan.
#
# IMPORTANT SAFETY WARNING:
# 1. Review all commands before running this script.
# 2. Some actions modify system preferences, firewall rules, or services.
# 3. Administrative privileges (sudo) are required for privileged operations.
# ==============================================================================

set -u

# Text styles
C_RESET=$'\033[0m'
C_BOLD=$'\033[1m'
C_GREEN=$'\033[92m'
C_YELLOW=$'\033[93m'
C_RED=$'\033[91m'
C_CYAN=$'\033[96m'
C_DIM=$'\033[2m'

# Check administrative privileges
if [[ $EUID -ne 0 ]]; then
    echo "${C_YELLOW}[!] WARNING: This script was not run with sudo/root privileges.${C_RESET}"
    echo "    Some system-level remediations may prompt for your password or fail."
    echo ""
    read -r -p "Do you want to continue anyway? [y/N]: " confirm_root
    case "$confirm_root" in
        [yY][eE][sS]|[yY])
            echo ""
            ;;
        *)
            echo "${C_RED}[*] Aborting. Please run with: sudo $0${C_RESET}"
            exit 1
            ;;
    esac
fi

EOF

    # Append metadata to script
    cat <<EOF >> "$output_file"
# Scan Metadata
# Scanner Version : macharden v${MACHAR_VERSION:-1.0.0}
# Generated On    : ${current_time}
# Hostname        : ${hostname}
# User            : ${current_user:-$user}
# OS Version      : ${os_product} ${os_version} (Build ${os_build}) [${arch}]
# Hardening Score : ${HARDENING_INDEX:-0.0}%
# Remediations    : ${total_fixes} total action(s)

echo "\${C_BOLD}\${C_CYAN}======================================================================\${C_RESET}"
echo "       \${C_BOLD}macharden - Applying Security Hardening Remediations\${C_RESET}"
echo "\${C_BOLD}\${C_CYAN}======================================================================\${C_RESET}"
echo "Target System : ${hostname} (${os_product} ${os_version})"
echo "Generated On  : ${current_time}"
echo "Total Actions : ${total_fixes}"
echo "\${C_DIM}----------------------------------------------------------------------\${C_RESET}"
echo ""

TOTAL_FIXES=${total_fixes}
SUCCESS_COUNT=0
FAILURE_COUNT=0

EOF

    if (( total_fixes == 0 )); then
        cat <<'EOF' >> "$output_file"
echo "${C_GREEN}[PASS] No security remediations required. All audited checks passed!${C_RESET}"
exit 0
EOF
    else
        # Confirmation prompt before executing any modifications
        cat <<'EOF' >> "$output_file"
read -r -p "${C_BOLD}Proceed with applying these ${TOTAL_FIXES} hardening fixes? [y/N]: ${C_RESET}" prompt_all
case "$prompt_all" in
    [yY][eE][sS]|[yY])
        echo ""
        ;;
    *)
        echo "${C_YELLOW}[*] Remediation cancelled by user.${C_RESET}"
        exit 0
        ;;
esac

EOF

        # Write each remediation item into the script
        local step_num=1
        for idx in "${fixable_indices[@]}"; do
            local id="${RES_IDS[idx]}"
            local cat="${RES_CATEGORIES[idx]}"
            local title="${RES_TITLES[idx]}"
            local st="${RES_STATUSES[idx]}"
            local weight="${RES_WEIGHTS[idx]}"
            local details="${RES_DETAILS[idx]}"
            local rem="${RES_REMEDIATIONS[idx]}"

            cat <<EOF >> "$output_file"
# ------------------------------------------------------------------------------
# [Step ${step_num}/${total_fixes}] ID: ${id} | Category: ${cat}
# Title  : ${title}
# Status : ${st} (Weight: ${weight})
# Finding: ${details}
# ------------------------------------------------------------------------------
echo "\${C_BOLD}[${step_num}/${total_fixes}]\${C_RESET} Fixing \${C_CYAN}${id}\${C_RESET}: ${title}..."
echo "      \${C_DIM}Command: ${rem}\${C_RESET}"

if ${rem}; then
    echo "      \${C_GREEN}[OK]\${C_RESET} Remediation applied successfully."
    (( ++SUCCESS_COUNT ))
else
    EXIT_CODE=\$?
    echo "      \${C_RED}[FAILED]\${C_RESET} Command exited with code \${EXIT_CODE}."
    (( ++FAILURE_COUNT ))
fi
echo ""

EOF
            (( ++step_num ))
        done

        # Write summary and footer
        cat <<'EOF' >> "$output_file"
echo "${C_BOLD}${C_CYAN}======================================================================${C_RESET}"
echo "                   ${C_BOLD}REMEDIATION COMPLETION SUMMARY${C_RESET}"
echo "${C_BOLD}${C_CYAN}======================================================================${C_RESET}"
echo "Total Planned  : ${TOTAL_FIXES}"
echo "Applied (${C_GREEN}OK${C_RESET})   : ${SUCCESS_COUNT}"
echo "Failed  (${C_RED}ERR${C_RESET})  : ${FAILURE_COUNT}"
echo ""

if [[ $FAILURE_COUNT -eq 0 ]]; then
    echo "${C_GREEN}${C_BOLD}✔ All hardening remediations completed successfully!${C_RESET}"
    echo "  Recommended: Re-run 'macharden' to verify improved Hardening Index."
else
    echo "${C_YELLOW}${C_BOLD}⚠ Some remediations encountered issues.${C_RESET}"
    echo "  Please inspect the log output above for details."
fi
echo ""
EOF
    fi

    # Make the script executable
    chmod +x "$output_file"

    if [[ "${MACHAR_QUIET:-0}" -eq 0 ]]; then
        ui_success "Remediation fix script generated: ${output_file}"
        ui_info "Execute via: ${COLOR_BOLD}sudo ./${output_file}${COLOR_RESET}"
    fi

    return 0
}

# Compatibility alias for CLI orchestrator
generate_remediation_script() {
    generate_fix_script "$@"
}

# ==============================================================================
# Interactively prompt and apply remediation fixes one-by-one
# Usage: apply_remediation_interactive
# ==============================================================================
apply_remediation_interactive() {
    local n=${#RES_IDS[@]}
    local fixable_indices=()

    for (( i = 1; i <= n; i++ )); do
        local st="${RES_STATUSES[i]}"
        local rem="${RES_REMEDIATIONS[i]}"
        if [[ ( "$st" == "FAIL" || "$st" == "WARN" ) && -n "$rem" ]]; then
            fixable_indices+=("$i")
        fi
    done

    local total_fixes=${#fixable_indices[@]}

    if (( total_fixes == 0 )); then
        echo ""
        ui_success "No security remediations required. All audited controls passed!"
        return 0
    fi

    echo ""
    echo "${COLOR_BOLD}${COLOR_BCYAN}======================================================================${COLOR_RESET}"
    echo "          ${COLOR_BOLD}INTERACTIVE HARDENING REMEDIATION MODE${COLOR_RESET}"
    echo "${COLOR_BOLD}${COLOR_BCYAN}======================================================================${COLOR_RESET}"
    echo "Found ${COLOR_BOLD}${total_fixes}${COLOR_RESET} remediable security findings."
    echo "Options: [${COLOR_BGREEN}y${COLOR_RESET}] Apply fix, [${COLOR_BYELLOW}n${COLOR_RESET}] Skip, [${COLOR_BCYAN}a${COLOR_RESET}] Apply all, [${COLOR_BRED}q${COLOR_RESET}] Quit."
    echo "${COLOR_DIM}----------------------------------------------------------------------${COLOR_RESET}"
    echo ""

    local apply_all=0
    local applied_count=0
    local skipped_count=0
    local failed_count=0
    local step_num=1

    for idx in "${fixable_indices[@]}"; do
        local id="${RES_IDS[idx]}"
        local cat="${RES_CATEGORIES[idx]}"
        local title="${RES_TITLES[idx]}"
        local st="${RES_STATUSES[idx]}"
        local weight="${RES_WEIGHTS[idx]}"
        local details="${RES_DETAILS[idx]}"
        local rem="${RES_REMEDIATIONS[idx]}"

        local badge
        if [[ "$st" == "FAIL" ]]; then
            badge="${COLOR_BRED}${COLOR_BOLD}[FAIL]${COLOR_RESET}"
        else
            badge="${COLOR_BYELLOW}${COLOR_BOLD}[WARN]${COLOR_RESET}"
        fi

        printf "  ${COLOR_BOLD}[%d/%d]${COLOR_RESET} %b ${COLOR_BOLD}%s${COLOR_RESET} - %s\n" \
            "$step_num" "$total_fixes" "$badge" "$id" "$title"
        printf "        ${COLOR_DIM}Category: %s | Weight: %s${COLOR_RESET}\n" "$cat" "$weight"
        if [[ -n "$details" ]]; then
            printf "        ${COLOR_DIM}Finding : %s${COLOR_RESET}\n" "$details"
        fi
        printf "        ${COLOR_BCYAN}Command : %s${COLOR_RESET}\n" "$rem"

        local do_apply=0
        if (( apply_all )); then
            do_apply=1
        else
            while true; do
                local response=""
                if [[ -r /dev/tty ]]; then
                    printf "        ${COLOR_BOLD}Apply this fix? [y/n/a/q]: ${COLOR_RESET}"
                    read -r response </dev/tty
                else
                    printf "        ${COLOR_BOLD}Apply this fix? [y/n/a/q]: ${COLOR_RESET}"
                    read -r response
                fi
                response="${response:l}"
                case "$response" in
                    y|yes)
                        do_apply=1
                        break
                        ;;
                    n|no|"")
                        do_apply=0
                        break
                        ;;
                    a|all)
                        apply_all=1
                        do_apply=1
                        break
                        ;;
                    q|quit)
                        ui_warn "Remediation aborted by user."
                        (( skipped_count += (total_fixes - step_num + 1) ))
                        break 2
                        ;;
                    *)
                        echo "        Please enter y, n, a, or q."
                        ;;
                esac
            done
        fi

        if (( do_apply )); then
            printf "        ${COLOR_DIM}Executing...${COLOR_RESET}\n"
            if eval "$rem"; then
                printf "        ${COLOR_BGREEN}${COLOR_BOLD}✔ Remediation applied successfully.${COLOR_RESET}\n"
                (( ++applied_count ))
            else
                local err_code=$?
                printf "        ${COLOR_BRED}${COLOR_BOLD}✖ Remediation failed (exit code %d).${COLOR_RESET}\n" "$err_code"
                (( ++failed_count ))
            fi
        else
            ui_info "Skipped [${id}]"
            (( ++skipped_count ))
        fi

        echo ""
        (( ++step_num ))
    done

    echo "${COLOR_DIM}----------------------------------------------------------------------${COLOR_RESET}"
    printf "  ${COLOR_BOLD}Remediation Summary:${COLOR_RESET} Applied: ${COLOR_BGREEN}%d${COLOR_RESET} | Skipped: ${COLOR_BYELLOW}%d${COLOR_RESET} | Failed: ${COLOR_BRED}%d${COLOR_RESET}\n" \
        "$applied_count" "$skipped_count" "$failed_count"
    echo ""

    return 0
}

# Compatibility alias for CLI orchestrator
apply_remediations() {
    apply_remediation_interactive "$@"
}

