#!/bin/zsh
# ==============================================================================
# macharden - lib/audit_hardening.sh
# OS Hardening Audit Module: SIP, FileVault, Gatekeeper, Screen Lock,
# Guest Account, Software Updates, and Sharing Services
# ==============================================================================

# Ensure record_result fallback exists if sourced standalone
if ! command -v record_result >/dev/null 2>&1 && ! typeset -f record_result >/dev/null 2>&1; then
    record_result() {
        printf "[%s] %s (%s): %s - %s\n" "$4" "$1" "$2" "$3" "$6"
    }
fi

# HARD-01: System Integrity Protection (SIP)
# Checks `csrutil status`. PASS if enabled, FAIL if disabled.
audit_sip() {
    local check_id="${1:-HARD-01}"
    local category="${2:-hardening}"
    local title="${3:-System Integrity Protection (SIP)}"
    local weight="${4:-10}"

    local res_status="FAIL"
    local details=""
    local remediation=""

    local csr_out
    csr_out=$(csrutil status 2>&1)

    if echo "$csr_out" | grep -qi "System Integrity Protection status: enabled"; then
        res_status="PASS"
        details="System Integrity Protection (SIP) is enabled and enforcing kernel/filesystem restrictions."
        remediation=""
    elif echo "$csr_out" | grep -qi "disabled"; then
        res_status="FAIL"
        details="System Integrity Protection (SIP) is disabled! System binaries, SIP NVRAM variables, and kernel extensions can be modified."
        remediation="Reboot into Recovery Mode (hold Cmd+R or Power button) and run: csrutil enable"
    else
        res_status="WARN"
        details="Unexpected SIP status: $(echo "$csr_out" | head -n 1)"
        remediation="Check SIP configuration manually via 'csrutil status'"
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# HARD-02: FileVault Disk Encryption
# Checks `fdesetup status`. PASS if FileVault is On, FAIL if Off.
audit_filevault() {
    local check_id="${1:-HARD-02}"
    local category="${2:-hardening}"
    local title="${3:-FileVault Full Disk Encryption}"
    local weight="${4:-10}"

    local res_status="FAIL"
    local details=""
    local remediation=""

    local fde_out
    fde_out=$(fdesetup status 2>&1)

    if echo "$fde_out" | grep -qi "FileVault is On"; then
        res_status="PASS"
        details="FileVault is enabled. Boot and APFS data volumes are encrypted with XTS-AES-128 at rest."
        remediation=""
    elif echo "$fde_out" | grep -qi "FileVault is Off"; then
        res_status="FAIL"
        details="FileVault is disabled! Local storage is unencrypted; data is accessible if the Mac is physically lost or stolen."
        remediation="sudo fdesetup enable"
    else
        res_status="WARN"
        details="FileVault status check returned: $(echo "$fde_out" | head -n 1)"
        remediation="sudo fdesetup status"
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# HARD-03: Gatekeeper Assessment
# Checks `spctl --status`. PASS if assessments enabled, FAIL if disabled.
audit_gatekeeper() {
    local check_id="${1:-HARD-03}"
    local category="${2:-hardening}"
    local title="${3:-Gatekeeper App Assessment}"
    local weight="${4:-9}"

    local res_status="FAIL"
    local details=""
    local remediation=""

    local spctl_out
    spctl_out=$(spctl --status 2>&1)

    if echo "$spctl_out" | grep -qi "assessments enabled"; then
        res_status="PASS"
        details="Gatekeeper assessment is enabled. macOS verifies application signatures and notarization before execution."
        remediation=""
    else
        res_status="FAIL"
        details="Gatekeeper assessment is disabled! Untrusted and unsigned third-party applications can execute without verification."
        remediation="sudo spctl --master-enable"
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# HARD-04: Screen Lock & Immediate Password Requirement
# Checks `defaults read com.apple.screensaver askForPassword` and `askForPasswordDelay`.
# PASS if askForPassword==1 and delay<=5, WARN if delay>5, FAIL if askForPassword==0.
audit_screenlock() {
    local check_id="${1:-HARD-04}"
    local category="${2:-hardening}"
    local title="${3:-Screen Lock Password Requirement}"
    local weight="${4:-6}"

    local res_status="FAIL"
    local details=""
    local remediation=""

    local ask_pw=""
    local ask_delay=""

    # Check user defaults domain
    ask_pw=$(defaults read com.apple.screensaver askForPassword 2>/dev/null || echo "")
    if [[ -z "$ask_pw" ]]; then
        ask_pw=$(defaults -currentHost read com.apple.screensaver askForPassword 2>/dev/null || echo "")
    fi

    ask_delay=$(defaults read com.apple.screensaver askForPasswordDelay 2>/dev/null || echo "")
    if [[ -z "$ask_delay" ]]; then
        ask_delay=$(defaults -currentHost read com.apple.screensaver askForPasswordDelay 2>/dev/null || echo "")
    fi

    # Fallback to sysadminctl if defaults keys are unpopulated (macOS Ventura/Sonoma/Sequoia)
    if [[ -z "$ask_pw" && -z "$ask_delay" ]]; then
        local sys_out
        sys_out=$(sysadminctl -screenLock status 2>&1 || echo "")
        if echo "$sys_out" | grep -qi "delay is 0 seconds"; then
            ask_pw="1"
            ask_delay="0"
        elif echo "$sys_out" | grep -qiE "delay is [0-9]+ seconds"; then
            ask_pw="1"
            ask_delay=$(echo "$sys_out" | sed -n 's/.*delay is \([0-9]*\) seconds.*/\1/p')
        fi
    fi

    # Default to 0 if not set or found
    [[ -z "$ask_pw" ]] && ask_pw="0"
    [[ -z "$ask_delay" ]] && ask_delay="0"

    if [[ "$ask_pw" == "0" ]]; then
        res_status="FAIL"
        details="Screen saver password requirement is disabled. The system can be accessed without authentication when idle."
        remediation="defaults write com.apple.screensaver askForPassword -int 1 && defaults write com.apple.screensaver askForPasswordDelay -int 0"
    elif [[ "$ask_pw" == "1" ]]; then
        if [[ "$ask_delay" =~ ^[0-9]+$ ]] && (( ask_delay > 5 )); then
            res_status="WARN"
            details="Screen lock requires password, but grace period delay is ${ask_delay}s (exceeds CIS recommended <= 5s)."
            remediation="defaults write com.apple.screensaver askForPasswordDelay -int 0"
        else
            res_status="PASS"
            details="Immediate screen lock password is required (delay: ${ask_delay}s)."
            remediation=""
        fi
    else
        res_status="WARN"
        details="Screen lock configuration is ambiguous (askForPassword=${ask_pw}, delay=${ask_delay})."
        remediation="defaults write com.apple.screensaver askForPassword -int 1 && defaults write com.apple.screensaver askForPasswordDelay -int 0"
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# HARD-05: Guest Account
# Checks `defaults read /Library/Preferences/com.apple.loginwindow GuestEnabled`.
# PASS if 0/disabled, FAIL if 1/enabled.
audit_guest_account() {
    local check_id="${1:-HARD-05}"
    local category="${2:-hardening}"
    local title="${3:-Guest Account Status}"
    local weight="${4:-5}"

    local res_status="PASS"
    local details=""
    local remediation=""

    local guest_val
    guest_val=$(defaults read /Library/Preferences/com.apple.loginwindow GuestEnabled 2>/dev/null || echo "0")

    if [[ "$guest_val" == "1" ]]; then
        res_status="FAIL"
        details="Guest user account is enabled on the login window, allowing unauthenticated physical logon."
        remediation="sudo defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled -bool false"
    else
        res_status="PASS"
        details="Guest user account is disabled."
        remediation=""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# HARD-06: Automatic Software Updates
# Checks `defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled` and `AutomaticallyInstallMacOSUpdates`.
# PASS if both 1, WARN if check is 0, SUGG if auto-install is 0.
audit_auto_updates() {
    local check_id="${1:-HARD-06}"
    local category="${2:-hardening}"
    local title="${3:-Automatic Software Updates}"
    local weight="${4:-6}"

    local res_status="PASS"
    local details=""
    local remediation=""

    local auto_check
    auto_check=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled 2>/dev/null || echo "")

    # Fallback to softwareupdate --schedule if key is not found
    if [[ -z "$auto_check" ]]; then
        if softwareupdate --schedule 2>&1 | grep -qi "turned on"; then
            auto_check="1"
        else
            auto_check="0"
        fi
    fi

    local auto_install
    auto_install=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates 2>/dev/null || echo "0")

    if [[ "$auto_check" == "0" ]]; then
        res_status="WARN"
        details="Automatic checking for software and security updates is disabled."
        remediation="sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true && sudo softwareupdate --schedule on"
    elif [[ "$auto_install" == "0" ]]; then
        res_status="SUGG"
        details="Automatic update check is enabled, but automatic background installation of macOS updates is disabled."
        remediation="sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates -bool true"
    else
        res_status="PASS"
        details="Automatic software update checking and automatic background installation are both enabled."
        remediation=""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# HARD-07: Unnecessary Sharing Services
# Checks if `smbd`, `nfsd`, `tftpd`, `com.openssh.sshd` or screen sharing (VNC) are active.
# PASS if all inactive, WARN/FAIL if active.
audit_sharing_services() {
    local check_id="${1:-HARD-07}"
    local category="${2:-hardening}"
    local title="${3:-Unnecessary Sharing Services}"
    local weight="${4:-7}"

    local res_status="PASS"
    local details=""
    local remediation=""

    local active_services=""
    local remed_commands=""

    # Check SMB (File Sharing)
    if pgrep -x smbd >/dev/null 2>&1 || launchctl list com.apple.smbd >/dev/null 2>&1; then
        active_services="${active_services:+$active_services, }SMB (File Sharing)"
        remed_commands="${remed_commands:+$remed_commands; }sudo launchctl disable system/com.apple.smbd"
    fi

    # Check NFS
    if pgrep -x nfsd >/dev/null 2>&1 || launchctl list com.apple.nfsd >/dev/null 2>&1; then
        active_services="${active_services:+$active_services, }NFS"
        remed_commands="${remed_commands:+$remed_commands; }sudo nfsd stop"
    fi

    # Check TFTP
    if pgrep -x tftpd >/dev/null 2>&1 || launchctl list com.apple.tftpd >/dev/null 2>&1; then
        active_services="${active_services:+$active_services, }TFTP"
        remed_commands="${remed_commands:+$remed_commands; }sudo launchctl disable system/com.apple.tftpd"
    fi

    # Check SSH (Remote Login)
    if pgrep -x sshd >/dev/null 2>&1 || launchctl list com.openssh.sshd >/dev/null 2>&1; then
        active_services="${active_services:+$active_services, }SSH (Remote Login)"
        remed_commands="${remed_commands:+$remed_commands; }sudo launchctl disable system/com.openssh.sshd"
    fi

    # Check Screen Sharing (VNC)
    if pgrep -x screensharingd >/dev/null 2>&1 || launchctl list com.apple.screensharing >/dev/null 2>&1 || lsof -nP -iTCP:5900 -sTCP:LISTEN >/dev/null 2>&1; then
        active_services="${active_services:+$active_services, }Screen Sharing (VNC)"
        remed_commands="${remed_commands:+$remed_commands; }sudo launchctl disable system/com.apple.screensharing"
    fi

    if [[ -z "$active_services" ]]; then
        res_status="PASS"
        details="No unnecessary remote sharing services (SMB, NFS, TFTP, SSH, Screen Sharing) are active."
        remediation=""
    else
        if echo "$active_services" | grep -qiE "TFTP|NFS"; then
            res_status="FAIL"
        else
            res_status="WARN"
        fi
        details="Active remote sharing services detected: ${active_services}"
        remediation="${remed_commands}"
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# Aliases for ID-based execution
audit_hard_01() { audit_sip "$@"; }
audit_hard_02() { audit_filevault "$@"; }
audit_hard_03() { audit_gatekeeper "$@"; }
audit_hard_04() { audit_screenlock "$@"; }
audit_hard_05() { audit_guest_account "$@"; }
audit_hard_06() { audit_auto_updates "$@"; }
audit_hard_07() { audit_sharing_services "$@"; }

# Category Runner
run_audit_hardening() {
    audit_sip
    audit_filevault
    audit_gatekeeper
    audit_screenlock
    audit_guest_account
    audit_auto_updates
    audit_sharing_services
}

# Auto-registration with engine.sh
register_hardening_checks() {
    if command -v register_check >/dev/null 2>&1 || typeset -f register_check >/dev/null 2>&1; then
        register_check "HARD-01" "hardening" "System Integrity Protection (SIP)" 10 audit_sip
        register_check "HARD-02" "hardening" "FileVault Full Disk Encryption" 10 audit_filevault
        register_check "HARD-03" "hardening" "Gatekeeper App Assessment" 9 audit_gatekeeper
        register_check "HARD-04" "hardening" "Screen Lock Password Requirement" 6 audit_screenlock
        register_check "HARD-05" "hardening" "Guest Account Status" 5 audit_guest_account
        register_check "HARD-06" "hardening" "Automatic Software Updates" 6 audit_auto_updates
        register_check "HARD-07" "hardening" "Unnecessary Sharing Services" 7 audit_sharing_services
    fi
}

register_hardening_checks
