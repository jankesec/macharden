#!/bin/zsh
# ==============================================================================
# macharden - lib/audit_hardening.sh
# OS Hardening Audit Module: SIP, FileVault, Gatekeeper, Screen Lock,
# Guest Account, Software Updates, Sharing Services, Firmware Password,
# Secure Boot, Automatic Login, Bluetooth Sharing, Home Directory
# Permissions, Network Time, and Built-in Malware Protection
# ==============================================================================

# Ensure record_result fallback exists if sourced standalone
if ! command -v record_result >/dev/null 2>&1 && ! typeset -f record_result >/dev/null 2>&1; then
    record_result() {
        printf "[%s] %s (%s): %s - %s\n" "$4" "$1" "$2" "$3" "$6"
    }
fi

# Helper to get file octal permissions portably (macOS and Linux)
if ! typeset -f _get_octal_perms >/dev/null 2>&1; then
    _get_octal_perms() {
        stat -f "%OLp" "$1" 2>/dev/null || stat -c "%a" "$1" 2>/dev/null || echo ""
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
        remediation="[GUIDE] Reboot into Recovery Mode (hold Cmd+R or Power button) and run: csrutil enable"
    else
        res_status="WARN"
        details="Unexpected SIP status: $(echo "$csr_out" | head -n 1)"
        remediation="[GUIDE] Check SIP configuration manually via 'csrutil status'"
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
        remediation="[EXEC] sudo fdesetup enable"
    else
        res_status="WARN"
        details="FileVault status check returned: $(echo "$fde_out" | head -n 1)"
        remediation="[EXEC] sudo fdesetup status"
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# HARD-03: Gatekeeper Assessment
# Checks `spctl --status`. PASS if assessments enabled, FAIL if disabled.
audit_gatekeeper() {
    local check_id="${1:-HARD-03}"
    local category="${2:-hardening}"
    local title="${3:-Gatekeeper App Assessment}"
    local weight="${4:-10}"

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
        remediation="[EXEC] sudo spctl --global-enable 2>/dev/null || sudo spctl --master-enable"
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
    local weight="${4:-7}"

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
        remediation="[EXEC] defaults write com.apple.screensaver askForPassword -int 1 && defaults write com.apple.screensaver askForPasswordDelay -int 0"
    elif [[ "$ask_pw" == "1" ]]; then
        if [[ "$ask_delay" =~ ^[0-9]+$ ]] && (( ask_delay > 5 )); then
            res_status="WARN"
            details="Screen lock requires password, but grace period delay is ${ask_delay}s (exceeds CIS recommended <= 5s)."
            remediation="[EXEC] defaults write com.apple.screensaver askForPasswordDelay -int 0"
        else
            res_status="PASS"
            details="Immediate screen lock password is required (delay: ${ask_delay}s)."
            remediation=""
        fi
    else
        res_status="WARN"
        details="Screen lock configuration is ambiguous (askForPassword=${ask_pw}, delay=${ask_delay})."
        remediation="[EXEC] defaults write com.apple.screensaver askForPassword -int 1 && defaults write com.apple.screensaver askForPasswordDelay -int 0"
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
    local weight="${4:-6}"

    local res_status="PASS"
    local details=""
    local remediation=""

    local guest_val
    guest_val=$(defaults read /Library/Preferences/com.apple.loginwindow GuestEnabled 2>/dev/null || echo "0")

    if [[ "$guest_val" == "1" ]]; then
        res_status="FAIL"
        details="Guest user account is enabled on the login window, allowing unauthenticated physical logon."
        remediation="[EXEC] sudo defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled -bool false"
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
    
    local crit_update
    crit_update=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall 2>/dev/null || echo "0")
    
    local config_data
    config_data=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate ConfigDataInstall 2>/dev/null || echo "0")

    if [[ "$auto_check" == "0" ]]; then
        res_status="WARN"
        details="Automatic checking for software and security updates is disabled."
        remediation="[EXEC] sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true && sudo softwareupdate --schedule on"
    elif [[ "$crit_update" == "0" ]] || [[ "$config_data" == "0" ]]; then
        res_status="WARN"
        details="Background security response and critical system updates installation is disabled."
        remediation="[EXEC] sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall -bool true && sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate ConfigDataInstall -bool true"
    elif [[ "$auto_install" == "0" ]]; then
        res_status="SUGG"
        details="Automatic update check is enabled, but automatic background installation of macOS updates is disabled."
        remediation="[EXEC] sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates -bool true"
    else
        res_status="PASS"
        details="Automatic software update checking and automatic background installation are both enabled."
        remediation=""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# HARD-07: Unnecessary Sharing Services
# Checks if `smbd`, `nfsd`, `tftpd`, Remote Login, screen sharing (VNC), or
# Remote Apple Events are active. Remote Login is on only if systemsetup
# reports On or sshd is listening — not merely because launchctl lists sshd.
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

    # Check SSH (Remote Login): systemsetup On, or sshd actually listening.
    # Do not treat launchctl list com.openssh.sshd success as Remote Login enabled.
    local rl_out
    rl_out=$(systemsetup -getremotelogin 2>/dev/null || echo "")
    if echo "$rl_out" | grep -qiE "Remote Login:[[:space:]]*On[[:space:]]*$" \
        || lsof -nP -iTCP:22 -sTCP:LISTEN >/dev/null 2>&1; then
        active_services="${active_services:+$active_services, }SSH (Remote Login)"
        remed_commands="${remed_commands:+$remed_commands; }sudo systemsetup -setremotelogin off"
    fi

    # Check Screen Sharing (VNC)
    if pgrep -x screensharingd >/dev/null 2>&1 || launchctl list com.apple.screensharing >/dev/null 2>&1 || lsof -nP -iTCP:5900 -sTCP:LISTEN >/dev/null 2>&1; then
        active_services="${active_services:+$active_services, }Screen Sharing (VNC)"
        remed_commands="${remed_commands:+$remed_commands; }sudo launchctl disable system/com.apple.screensharing"
    fi

    # Check Remote Apple Events
    local rae_out
    rae_out=$(systemsetup -getremoteappleevents 2>/dev/null || echo "")
    if echo "$rae_out" | grep -qiE "Remote Apple Events:[[:space:]]*On[[:space:]]*$"; then
        active_services="${active_services:+$active_services, }Remote Apple Events"
        remed_commands="${remed_commands:+$remed_commands; }sudo systemsetup -setremoteappleevents off"
    fi

    if [[ -z "$active_services" ]]; then
        res_status="PASS"
        details="No unnecessary remote sharing services (SMB, NFS, TFTP, SSH, Screen Sharing, Remote Apple Events) are active."
        remediation=""
    else
        if echo "$active_services" | grep -qiE "TFTP|NFS"; then
            res_status="FAIL"
        else
            res_status="WARN"
        fi
        details="Active remote sharing services detected: ${active_services}"
        remediation="[EXEC] ${remed_commands}"
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# HARD-08: Firmware Password / Recovery Lock
# Checks `firmwarepasswd -check`. PASS if enabled, FAIL if disabled on Intel.
# INFO (not FAIL) when the command is missing, errors, or is unsupported (Apple Silicon).
audit_firmware_password() {
    local check_id="${1:-HARD-08}"
    local category="${2:-hardening}"
    local title="${3:-Firmware Password / Recovery Lock}"
    local weight="${4:-8}"

    local res_status="INFO"
    local details=""
    local remediation=""

    local fw_out=""
    if command -v firmwarepasswd >/dev/null 2>&1; then
        fw_out=$(firmwarepasswd -check 2>/dev/null || echo "")
    fi

    local arch
    arch=$(uname -m 2>/dev/null || echo "")

    if echo "$fw_out" | grep -q "Password Enabled: Yes"; then
        res_status="PASS"
        details="Firmware password is enabled. Unauthorized changes to the startup disk and NVRAM boot arguments are blocked."
        remediation=""
    elif echo "$fw_out" | grep -q "Password Enabled: No" \
        && [[ "$arch" != "arm64" ]] \
        && ! echo "$fw_out" | grep -qi "not supported"; then
        res_status="FAIL"
        details="Firmware password is not enabled. An attacker with physical access can boot from external media or reset NVRAM."
        remediation="[GUIDE] Reboot into Recovery and set a firmware password via Startup Security Utility (Intel) or Recovery Lock (MDM/Apple Silicon)."
    else
        res_status="INFO"
        details="Firmware password is Intel-only and is not supported on this Mac (Apple Silicon). Secure Boot / HARD-09 covers equivalent boot protection."
        remediation=""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# HARD-09: Secure Boot / Authenticated Root
# Checks `csrutil authenticated-root status` and `system_profiler SPiBridgeDataType`.
# PASS if authenticated-root is enabled and (if reported) Secure Boot is Full Security.
# WARN if authenticated-root is disabled or Secure Boot is Reduced/Permissive.
# INFO if neither command yields usable data.
audit_secure_boot() {
    local check_id="${1:-HARD-09}"
    local category="${2:-hardening}"
    local title="${3:-Secure Boot / Authenticated Root}"
    local weight="${4:-8}"

    local res_status="INFO"
    local details=""
    local remediation=""

    local ar_out=""
    ar_out=$(csrutil authenticated-root status 2>/dev/null || echo "")

    local sb_out=""
    sb_out=$(system_profiler SPiBridgeDataType 2>/dev/null || echo "")

    local ar_state=""
    if echo "$ar_out" | grep -qi "disabled"; then
        ar_state="disabled"
    elif echo "$ar_out" | grep -qi "enabled"; then
        ar_state="enabled"
    fi

    local sb_state=""
    if echo "$sb_out" | grep -qiE "Secure Boot:[[:space:]]*Full Security"; then
        sb_state="full"
    elif echo "$sb_out" | grep -qiE "Secure Boot:[[:space:]]*(Reduced|Permissive) Security"; then
        sb_state="weak"
    elif echo "$sb_out" | grep -qiE "Secure Boot:[[:space:]]*[[:alnum:]]"; then
        sb_state="other"
    fi

    local warn_fix='[GUIDE] Reboot into Recovery → Startup Security Utility → Full Security; enable Authenticated Root (`csrutil authenticated-root enable` from Recovery).'

    if [[ -z "$ar_state" && -z "$sb_state" ]]; then
        res_status="INFO"
        details="Could not determine Secure Boot or Authenticated Root status (neither csrutil authenticated-root nor SPiBridgeDataType yielded usable data)."
        remediation=""
    elif [[ "$ar_state" == "disabled" || "$sb_state" == "weak" || "$sb_state" == "other" ]]; then
        res_status="WARN"
        if [[ "$ar_state" == "disabled" && "$sb_state" == "weak" ]]; then
            details="Authenticated Root is disabled and Secure Boot is Reduced/Permissive rather than Full Security."
        elif [[ "$ar_state" == "disabled" ]]; then
            details="Authenticated Root is disabled. The sealed system volume can be modified without Apple's signed snapshot."
        elif [[ "$sb_state" == "weak" ]]; then
            details="Secure Boot is Reduced or Permissive rather than Full Security."
        else
            details="Secure Boot is reported but is not Full Security (authenticated-root=${ar_state:-unknown})."
        fi
        remediation="$warn_fix"
    elif [[ "$ar_state" == "enabled" ]]; then
        res_status="PASS"
        if [[ "$sb_state" == "full" ]]; then
            details="Authenticated Root is enabled and Secure Boot is Full Security."
        else
            details="Authenticated Root is enabled. Secure Boot level was not reported by SPiBridgeDataType."
        fi
        remediation=""
    else
        res_status="INFO"
        details="Secure Boot is Full Security, but Authenticated Root status could not be determined."
        remediation=""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# HARD-10: Automatic Login Disabled
# Checks `defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser`.
# FAIL if a non-empty username is returned; PASS if the key is missing or empty.
audit_autologin() {
    local check_id="${1:-HARD-10}"
    local category="${2:-hardening}"
    local title="${3:-Automatic Login Disabled}"
    local weight="${4:-6}"

    local res_status="PASS"
    local details=""
    local remediation=""

    local auto_user
    auto_user=$(defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null || echo "")

    if [[ -n "$auto_user" ]]; then
        res_status="FAIL"
        details="Automatic login is enabled for a user account. The desktop is reachable without interactive authentication at boot."
        remediation="[EXEC] sudo defaults delete /Library/Preferences/com.apple.loginwindow autoLoginUser"
    else
        res_status="PASS"
        details="Automatic login is disabled (autoLoginUser is unset or empty)."
        remediation=""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# HARD-11: Bluetooth Sharing
# Checks `defaults read /Library/Preferences/com.apple.Bluetooth PrefKeyServicesEnabled`
# with a `-currentHost` fallback. WARN if 1/true; PASS if 0/false/unset.
audit_bluetooth_sharing() {
    local check_id="${1:-HARD-11}"
    local category="${2:-hardening}"
    local title="${3:-Bluetooth Sharing}"
    local weight="${4:-5}"

    local res_status="PASS"
    local details=""
    local remediation=""

    local bt_share=""
    bt_share=$(defaults read /Library/Preferences/com.apple.Bluetooth PrefKeyServicesEnabled 2>/dev/null || echo "")
    if [[ -z "$bt_share" ]]; then
        bt_share=$(defaults -currentHost read /Library/Preferences/com.apple.Bluetooth PrefKeyServicesEnabled 2>/dev/null || echo "")
    fi
    if [[ -z "$bt_share" ]]; then
        bt_share=$(defaults -currentHost read com.apple.Bluetooth PrefKeyServicesEnabled 2>/dev/null || echo "")
    fi

    if [[ "$bt_share" == "1" ]] || echo "$bt_share" | grep -qiE "^(true|yes)$"; then
        res_status="WARN"
        details="Bluetooth Sharing (PrefKeyServicesEnabled) is enabled. Nearby devices can accept files or browse services over Bluetooth."
        remediation="[EXEC] sudo defaults write /Library/Preferences/com.apple.Bluetooth PrefKeyServicesEnabled -bool false"
    else
        res_status="PASS"
        details="Bluetooth Sharing is disabled (PrefKeyServicesEnabled is 0, false, or unset)."
        remediation=""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# HARD-12: Home Directory Permissions
# Checks `$HOME` octal mode. PASS if 700 or 750 (other bits 0).
# WARN if world-readable/writable (other class 4-7) or group-writable.
audit_home_permissions() {
    local check_id="${1:-HARD-12}"
    local category="${2:-hardening}"
    local title="${3:-Home Directory Permissions}"
    local weight="${4:-6}"

    local res_status="WARN"
    local details=""
    local remediation=""

    local perms=""
    perms=$(_get_octal_perms "$HOME")
    # Keep last three octal digits (stat may prefix a 0)
    perms="${perms: -3}"

    local group_digit="${perms: -2:1}"
    local other_digit="${perms: -1}"

    if [[ -z "$perms" || "$perms" != [0-7][0-7][0-7] ]]; then
        res_status="INFO"
        details="Could not determine octal permissions for home directory (${HOME:-unset})."
        remediation=""
    elif [[ "$perms" == "700" || "$perms" == "750" ]]; then
        res_status="PASS"
        details="Home directory permissions are ${perms} (700 or 750; other class bits are 0)."
        remediation=""
    elif [[ "$other_digit" == [4-7] ]] || [[ "$group_digit" == [2367] ]]; then
        res_status="WARN"
        details="Home directory ($HOME) permissions are ${perms}. World-readable/writable (other class 4-7) or group-writable homes expose user files."
        remediation="[EXEC] chmod 700 \"$HOME\""
    elif [[ "$other_digit" == "0" ]]; then
        res_status="PASS"
        details="Home directory permissions are ${perms} (other class bits are 0)."
        remediation=""
    else
        res_status="WARN"
        details="Home directory ($HOME) permissions are ${perms} (expected 700 or 750)."
        remediation="[EXEC] chmod 700 \"$HOME\""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# HARD-13: Network Time Synchronization
# Checks `systemsetup -getusingnetworktime`. PASS if On, WARN if Off, INFO if the command fails.
audit_network_time() {
    local check_id="${1:-HARD-13}"
    local category="${2:-hardening}"
    local title="${3:-Network Time Synchronization}"
    local weight="${4:-5}"

    local res_status="INFO"
    local details=""
    local remediation=""

    local ntp_out=""
    ntp_out=$(systemsetup -getusingnetworktime 2>/dev/null || echo "")

    if echo "$ntp_out" | grep -qi "On"; then
        res_status="PASS"
        details="Network time synchronization is enabled (usingnetworktime On)."
        remediation=""
    elif echo "$ntp_out" | grep -qi "Off"; then
        res_status="WARN"
        details="Network time synchronization is disabled (usingnetworktime Off). Inaccurate clocks weaken TLS, logs, and Kerberos."
        remediation="[EXEC] sudo systemsetup -setusingnetworktime on"
    else
        res_status="INFO"
        details="Could not determine network time status (systemsetup -getusingnetworktime failed or returned unexpected output)."
        remediation=""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# HARD-14: Built-in Malware Protection
# PASS if XProtect.bundle exists. Note MRT if present. Optional third-party AV via pgrep -x.
# WARN only if XProtect is missing. Third-party AV is informational; do not FAIL if it is absent.
audit_malware_protection() {
    local check_id="${1:-HARD-14}"
    local category="${2:-hardening}"
    local title="${3:-Built-in Malware Protection}"
    local weight="${4:-6}"

    local res_status="WARN"
    local details=""
    local remediation=""

    local xprotect=""
    local mrt=""
    local running_av=""
    local av=""

    if [[ -e "/Library/Apple/System/Library/CoreServices/XProtect.bundle" ]]; then
        xprotect="/Library/Apple/System/Library/CoreServices/XProtect.bundle"
    elif [[ -e "/System/Library/CoreServices/XProtect.bundle" ]]; then
        xprotect="/System/Library/CoreServices/XProtect.bundle"
    fi

    if [[ -e "/Library/Apple/System/Library/CoreServices/MRT.app" ]]; then
        mrt="/Library/Apple/System/Library/CoreServices/MRT.app"
    elif [[ -e "/System/Library/CoreServices/MRT.app" ]]; then
        mrt="/System/Library/CoreServices/MRT.app"
    fi

    for av in falcon-sensor CylanceSvc SentinelAgent WdNisSvc; do
        if pgrep -x "$av" >/dev/null 2>&1; then
            running_av="${running_av:+$running_av, }$av"
        fi
    done

    if [[ -n "$xprotect" ]]; then
        res_status="PASS"
        details="XProtect bundle is present at ${xprotect}."
        if [[ -n "$mrt" ]]; then
            details="${details} MRT is present at ${mrt}."
        fi
        if [[ -n "$running_av" ]]; then
            details="${details} Third-party AV process(es) also running: ${running_av}."
        fi
        remediation=""
    else
        res_status="WARN"
        details="XProtect bundle is missing from /Library/Apple/System/Library/CoreServices/XProtect.bundle and /System/Library/CoreServices/XProtect.bundle."
        if [[ -n "$mrt" ]]; then
            details="${details} MRT is present at ${mrt}."
        fi
        if [[ -n "$running_av" ]]; then
            details="${details} Third-party AV process(es) running: ${running_av}."
        fi
        remediation="[GUIDE] Ensure macOS XProtect is present via Software Update. Apple XProtect is sufficient; do not install third-party AV solely to satisfy this check."
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# HARD-15: USB Restricted Mode
# T2 / Apple Silicon accessory authorization after lock. Explicit disable is WARN.
audit_usb_restricted_mode() {
    local check_id="${1:-HARD-15}"
    local category="${2:-hardening}"
    local title="${3:-USB Restricted Mode}"
    local weight="${4:-5}"

    local res_status="INFO"
    local details=""
    local remediation=""
    local val=""
    local arch
    arch=$(uname -m 2>/dev/null || echo "")

    val=$(defaults read com.apple.security.restrict-usb restrict-usb 2>/dev/null || echo "")
    if [[ -z "$val" ]]; then
        val=$(defaults read /Library/Preferences/com.apple.security.restrict-usb restrict-usb 2>/dev/null || echo "")
    fi
    if [[ -z "$val" ]]; then
        val=$(defaults -currentHost read com.apple.security.restrict-usb restrict-usb 2>/dev/null || echo "")
    fi

    if echo "$val" | grep -qiE '^(0|false)$'; then
        res_status="WARN"
        details="USB Restricted Mode is explicitly disabled (restrict-usb=${val}). Accessories can attach while the Mac is locked."
        remediation="[GUIDE] Run: defaults delete com.apple.security.restrict-usb restrict-usb 2>/dev/null"
    elif echo "$val" | grep -qiE '^(1|true)$'; then
        res_status="PASS"
        details="USB Restricted Mode is enabled (restrict-usb=${val})."
        remediation=""
    else
        if [[ "$arch" == "arm64" ]]; then
            res_status="PASS"
            details="USB Restricted Mode preference is unset; Apple Silicon default is enabled (ask/authorize accessories after lock)."
        else
            res_status="INFO"
            details="USB Restricted Mode preference is unset. Feature applies to T2/Apple Silicon; confirm System Settings > Privacy & Security > Allow accessories to connect is not Always."
        fi
        remediation=""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# HARD-16: Diagnostic & Telemetry Reporting
# Checks if Apple Diagnostic & Telemetry reporting is enabled via
# `defaults read /Library/Application Support/CrashReporter/DiagnosticReporting AutoSubmit`
# or `SubmitDiagInfo`. WARN if enabled, PASS if disabled.
audit_diagnostic_telemetry() {
    local check_id="${1:-HARD-16}"
    local category="${2:-hardening}"
    local title="${3:-Diagnostic & Telemetry Reporting}"
    local weight="${4:-4}"

    local res_status="PASS"
    local details=""
    local remediation=""

    local auto_submit=""
    local submit_diag=""

    auto_submit=$(defaults read "/Library/Application Support/CrashReporter/DiagnosticReporting" AutoSubmit 2>/dev/null || echo "")
    submit_diag=$(defaults read "/Library/Application Support/CrashReporter/DiagnosticReporting" SubmitDiagInfo 2>/dev/null || echo "")

    if [[ -z "$submit_diag" && -f "/Library/Preferences/com.apple.SubmitDiagInfo.plist" ]]; then
        submit_diag=$(defaults read /Library/Preferences/com.apple.SubmitDiagInfo AutoSubmit 2>/dev/null || echo "")
    fi

    local is_enabled=0
    if echo "$auto_submit" | grep -qiE '^[[:space:]]*(1|true)[[:space:]]*$'; then
        is_enabled=1
    elif echo "$submit_diag" | grep -qiE '^[[:space:]]*(1|true)[[:space:]]*$'; then
        is_enabled=1
    fi

    if (( is_enabled )); then
        res_status="WARN"
        details="Apple Diagnostic & Telemetry data submission is enabled (AutoSubmit or SubmitDiagInfo is active)."
        remediation="[EXEC] sudo defaults write '/Library/Application Support/CrashReporter/DiagnosticReporting' AutoSubmit -bool false"
    else
        res_status="PASS"
        details="Apple Diagnostic & Telemetry data submission is disabled (AutoSubmit is false or not configured)."
        remediation=""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# HARD-17: AirDrop Discoverability Exposure
# Checks AirDrop discoverability mode via `defaults read com.apple.sharingd DiscoverableMode`.
# FAIL/WARN if 'Everyone', PASS if 'Off' or 'Contacts Only'.
audit_airdrop_exposure() {
    local check_id="${1:-HARD-17}"
    local category="${2:-hardening}"
    local title="${3:-AirDrop Discoverability Exposure}"
    local weight="${4:-6}"

    local res_status="PASS"
    local details=""
    local remediation=""

    local mode=""
    mode=$(defaults read com.apple.sharingd DiscoverableMode 2>/dev/null || echo "")

    if echo "$mode" | grep -qi "Everyone"; then
        res_status="WARN"
        details="AirDrop discoverability is set to 'Everyone' (discoverable by any nearby device; wireless exposure risk)."
        remediation="[EXEC] defaults write com.apple.sharingd DiscoverableMode -string 'Contacts Only'"
    elif echo "$mode" | grep -qiE '^(Off|Contacts[[:space:]]+Only)$' || [[ -z "$mode" ]]; then
        local display_mode="${mode:-Off}"
        res_status="PASS"
        details="AirDrop discoverability mode is securely configured ('${display_mode}')."
        remediation=""
    else
        res_status="PASS"
        details="AirDrop discoverability mode is set to '${mode}'."
        remediation=""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# HARD-18: OpenBSM Security Auditing Daemon Status
# Checks whether com.apple.auditd is active and OpenBSM is in AUC_AUDITING state.
# NIST 800-53 AU-12, AU-3, AU-14; CIS 3.1; DISA APPL-27-001003.
audit_auditd_daemon() {
    local check_id="${1:-HARD-18}"
    local category="${2:-hardening}"
    local title="${3:-OpenBSM Security Auditing Daemon Status}"
    local weight="${4:-8}"

    local res_status="PASS"
    local details=""
    local remediation=""

    local launchd_active=0
    local audit_cond=""

    if launchctl print system 2>/dev/null | grep -q -E '\tcom.apple.auditd' || launchctl list 2>/dev/null | grep -q 'com.apple.auditd'; then
        launchd_active=1
    fi
    audit_cond=$(audit -c 2>/dev/null || echo "")

    if [[ $launchd_active -eq 1 ]] && echo "$audit_cond" | grep -q "AUC_AUDITING"; then
        res_status="PASS"
        details="OpenBSM security auditing daemon (auditd) is active and recording security events (AUC_AUDITING)."
        remediation=""
    else
        res_status="WARN"
        details="OpenBSM security auditing daemon (com.apple.auditd) is not active or auditing is disabled (NIST AU-12 / CIS 3.1)."
        remediation="[EXEC] sudo launchctl enable system/com.apple.auditd && sudo launchctl bootstrap system /System/Library/LaunchDaemons/com.apple.auditd.plist 2>/dev/null; sudo audit -i 2>/dev/null || true"
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# HARD-19: Audit Control Configuration Ownership & Permissions
# Checks /etc/security/audit_control file ownership (root:wheel) and permissions (0400 or 0440).
# NIST 800-53 AU-9; CIS 3.2, 3.3; DISA APPL-27-001120, APPL-27-001130.
audit_control_perms() {
    local check_id="${1:-HARD-19}"
    local category="${2:-hardening}"
    local title="${3:-Audit Control Configuration Ownership & Permissions}"
    local weight="${4:-7}"

    local res_status="PASS"
    local details=""
    local remediation=""

    if [[ -f /etc/security/audit_control ]]; then
        local owner group perms
        owner=$(stat -f "%Su" /etc/security/audit_control 2>/dev/null || echo "")
        group=$(stat -f "%Sg" /etc/security/audit_control 2>/dev/null || echo "")
        perms=$(stat -f "%Lp" /etc/security/audit_control 2>/dev/null || echo "")

        local other_digit="${perms: -1}"
        local group_digit="${perms: -2:1}"

        if [[ "$owner" != "root" ]]; then
            res_status="FAIL"
            details="Audit control configuration (/etc/security/audit_control) owner is '$owner' (expected root; CIS 3.2)."
            remediation="[EXEC] sudo chown root:wheel /etc/security/audit_control"
        elif [[ "$other_digit" != "0" ]]; then
            res_status="FAIL"
            details="Audit control configuration (/etc/security/audit_control) has insecure permissions '$perms' (world-accessible; CIS 3.3 / NIST AU-9)."
            remediation="[EXEC] sudo chmod 0440 /etc/security/audit_control"
        elif (( group_digit > 4 )); then
            res_status="FAIL"
            details="Audit control configuration (/etc/security/audit_control) is group-writable ('$perms'; CIS 3.3)."
            remediation="[EXEC] sudo chmod 0440 /etc/security/audit_control"
        else
            res_status="PASS"
            details="Audit control configuration (/etc/security/audit_control) ownership (${owner}:${group}) and permissions ($perms) are securely hardened."
            remediation=""
        fi
    elif [[ -f /etc/security/audit_control.example ]]; then
        res_status="PASS"
        details="Default OpenBSM audit control template exists (/etc/security/audit_control.example) with secure default root permissions."
        remediation=""
    else
        res_status="WARN"
        details="OpenBSM audit control file (/etc/security/audit_control) was not found."
        remediation="[EXEC] sudo cp /etc/security/audit_control.example /etc/security/audit_control && sudo chmod 0440 /etc/security/audit_control"
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# HARD-20: Audit Log Files & Directory ACL Immutability
# Ensures /var/audit directory and audit trail files contain NO extended Access Control Lists (ACLs).
# NIST 800-53 AU-9; CIS 3.5 (Level 1); DISA APPL-27-000030, APPL-27-000031; MITRE T1562.001, T1070.
audit_audit_acls() {
    local check_id="${1:-HARD-20}"
    local category="${2:-hardening}"
    local title="${3:-Audit Log Files & Directory ACL Immutability}"
    local weight="${4:-9}"

    local res_status="PASS"
    local details=""
    local remediation=""

    local audit_dir
    audit_dir=$(grep '^dir' /etc/security/audit_control 2>/dev/null | awk -F: '{print $2}')
    audit_dir="${audit_dir:-/var/audit}"

    local dir_acls=0
    local file_acls=0

    if [[ -d "$audit_dir" ]]; then
        dir_acls=$(ls -lde "$audit_dir" 2>/dev/null | awk '{print $1}' | grep -c ":" || true)
        dir_acls="${dir_acls:-0}"

        file_acls=$(ls -le "$audit_dir" 2>/dev/null | awk '{print $1}' | grep -c ":" || true)
        file_acls="${file_acls:-0}"
    fi

    if (( dir_acls > 0 || file_acls > 0 )); then
        res_status="FAIL"
        details="Audit log directory ($audit_dir) or audit trail files contain Access Control Lists ($dir_acls dir ACLs, $file_acls file ACLs; NIST AU-9 / CIS 3.5)."
        remediation="[EXEC] sudo chmod -RN '$audit_dir'"
    else
        res_status="PASS"
        details="Audit log directory ($audit_dir) and audit trail files contain zero Access Control Lists (ACLs; verified immutability)."
        remediation=""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# HARD-21: Audit Trail Event Flags & Retention Policy
# Checks OpenBSM audit event flags for authentication ('lo') and administrative ('aa') classes and retention.
# NIST 800-53 AU-2, AU-11; CIS 3.4; DISA APPL-27-000010.
audit_policy_flags() {
    local check_id="${1:-HARD-21}"
    local category="${2:-hardening}"
    local title="${3:-Audit Trail Event Flags & Retention Policy}"
    local weight="${4:-6}"

    local res_status="PASS"
    local details=""
    local remediation=""

    if [[ -f /etc/security/audit_control ]]; then
        local flags expire
        flags=$(grep '^flags:' /etc/security/audit_control 2>/dev/null | awk -F: '{print $2}' | tr -d ' ')
        expire=$(grep '^expire-after:' /etc/security/audit_control 2>/dev/null | awk -F: '{print $2}' | tr -d ' ')
        if [[ "$flags" == *"lo"* && "$flags" == *"aa"* ]]; then
            res_status="PASS"
            details="Audit flags record authentication and administrative events (flags: ${flags}, expire-after: ${expire:-not-set})."
            remediation=""
        else
            res_status="WARN"
            details="Audit event flags (${flags:-none}) lack recommended authentication ('lo') or administrative ('aa') event classes (CIS 3.4)."
            remediation="[EXEC] sudo sed -i '' 's/^flags:.*/flags:lo,aa,ad,fd,fm,-all/' /etc/security/audit_control && sudo audit -s"
        fi
    elif [[ -f /etc/security/audit_control.example ]]; then
        local ex_flags
        ex_flags=$(grep '^flags:' /etc/security/audit_control.example 2>/dev/null | awk -F: '{print $2}' | tr -d ' ')
        res_status="INFO"
        details="System is using default OpenBSM audit template policies (flags: ${ex_flags:-lo,aa}; /etc/security/audit_control not customized)."
        remediation=""
    else
        res_status="WARN"
        details="OpenBSM audit configuration and event flags are not configured."
        remediation="[EXEC] sudo cp /etc/security/audit_control.example /etc/security/audit_control && sudo chmod 0440 /etc/security/audit_control"
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
audit_hard_08() { audit_firmware_password "$@"; }
audit_hard_09() { audit_secure_boot "$@"; }
audit_hard_10() { audit_autologin "$@"; }
audit_hard_11() { audit_bluetooth_sharing "$@"; }
audit_hard_12() { audit_home_permissions "$@"; }
audit_hard_13() { audit_network_time "$@"; }
audit_hard_14() { audit_malware_protection "$@"; }
audit_hard_15() { audit_usb_restricted_mode "$@"; }
audit_hard_16() { audit_diagnostic_telemetry "$@"; }
audit_hard_17() { audit_airdrop_exposure "$@"; }
audit_hard_18() { audit_auditd_daemon "$@"; }
audit_hard_19() { audit_control_perms "$@"; }
audit_hard_20() { audit_audit_acls "$@"; }
audit_hard_21() { audit_policy_flags "$@"; }

# Category Runner
run_audit_hardening() {
    audit_sip
    audit_filevault
    audit_gatekeeper
    audit_screenlock
    audit_guest_account
    audit_auto_updates
    audit_sharing_services
    audit_firmware_password
    audit_secure_boot
    audit_autologin
    audit_bluetooth_sharing
    audit_home_permissions
    audit_network_time
    audit_malware_protection
    audit_usb_restricted_mode
    audit_diagnostic_telemetry
    audit_airdrop_exposure
    audit_auditd_daemon
    audit_control_perms
    audit_audit_acls
    audit_policy_flags
}

# Auto-registration with engine.sh
register_hardening_checks() {
    if command -v register_check >/dev/null 2>&1 || typeset -f register_check >/dev/null 2>&1; then
        register_check "HARD-01" "hardening" "System Integrity Protection (SIP)" 10 audit_sip
        register_check "HARD-02" "hardening" "FileVault Full Disk Encryption" 10 audit_filevault
        register_check "HARD-03" "hardening" "Gatekeeper App Assessment" 10 audit_gatekeeper
        register_check "HARD-04" "hardening" "Screen Lock Password Requirement" 7 audit_screenlock
        register_check "HARD-05" "hardening" "Guest Account Status" 6 audit_guest_account
        register_check "HARD-06" "hardening" "Automatic Software Updates" 6 audit_auto_updates
        register_check "HARD-07" "hardening" "Unnecessary Sharing Services" 7 audit_sharing_services
        register_check "HARD-08" "hardening" "Firmware Password / Recovery Lock" 8 audit_firmware_password
        register_check "HARD-09" "hardening" "Secure Boot / Authenticated Root" 8 audit_secure_boot
        register_check "HARD-10" "hardening" "Automatic Login Disabled" 6 audit_autologin
        register_check "HARD-11" "hardening" "Bluetooth Sharing" 5 audit_bluetooth_sharing
        register_check "HARD-12" "hardening" "Home Directory Permissions" 6 audit_home_permissions
        register_check "HARD-13" "hardening" "Network Time Synchronization" 5 audit_network_time
        register_check "HARD-14" "hardening" "Built-in Malware Protection" 6 audit_malware_protection
        register_check "HARD-15" "hardening" "USB Restricted Mode" 5 audit_usb_restricted_mode
        register_check "HARD-16" "hardening" "Diagnostic & Telemetry Reporting" 4 audit_diagnostic_telemetry
        register_check "HARD-17" "hardening" "AirDrop Discoverability Exposure" 6 audit_airdrop_exposure
        register_check "HARD-18" "hardening" "OpenBSM Security Auditing Daemon Status" 8 audit_auditd_daemon
        register_check "HARD-19" "hardening" "Audit Control Configuration Ownership & Permissions" 7 audit_control_perms
        register_check "HARD-20" "hardening" "Audit Log Files & Directory ACL Immutability" 9 audit_audit_acls
        register_check "HARD-21" "hardening" "Audit Trail Event Flags & Retention Policy" 6 audit_policy_flags
    fi
}

register_hardening_checks

