#!/bin/zsh
# ==============================================================================
# macharden - lib/audit_persistence.sh
# Persistence Mechanisms Audit Module: User/System LaunchAgents,
# System LaunchDaemons, Crontabs, Login Items, Authorized Keys, Sudoers,
# Privileged Helper Tools, and Printer Sharing
# ==============================================================================

# Ensure record_result fallback exists if sourced standalone
if ! command -v record_result >/dev/null 2>&1 && ! typeset -f record_result >/dev/null 2>&1; then
    record_result() {
        printf "[%s] %s (%s): %s - %s\n" "$4" "$1" "$2" "$3" "$6"
    }
fi

# Helper to extract the program/binary path from a plist
_get_plist_program() {
    local plist="$1"
    local prog=""

    # Try Program key first
    prog=$(defaults read "$plist" Program 2>/dev/null || echo "")
    if [[ -z "$prog" ]]; then
        # Try first element of ProgramArguments
        prog=$(defaults read "$plist" ProgramArguments 2>/dev/null | grep -E '^[[:space:]]+' | head -n 1 | sed -E 's/^[[:space:]]*"?//; s/"?[,;[:space:]]*$//')
    fi
    # Strip any lingering quotes, commas, or semicolons
    prog=$(echo "$prog" | sed -E 's/^[[:space:]]*"?//; s/"?[,;[:space:]]*$//')
    echo "$prog"
}

# PERS-01: LaunchAgents Persistence Review
# Lists items in `~/Library/LaunchAgents` and `/Library/LaunchAgents`.
# Identifies suspicious, unsigned, or non-standard entries.
audit_launch_agents() {
    local check_id="${1:-PERS-01}"
    local category="${2:-persistence}"
    local title="${3:-LaunchAgents Persistence Review}"
    local weight="${4:-7}"

    local res_status="PASS"
    local details=""
    local remediation=""

    local user_agents_dir="$HOME/Library/LaunchAgents"
    local sys_agents_dir="/Library/LaunchAgents"

    local total_count=0
    local suspicious_list=""
    local custom_list=""
    local fix_cmds=""
    local plist=""
    local prog=""

    # 1. Inspect User LaunchAgents (~/Library/LaunchAgents)
    if [[ -d "$user_agents_dir" ]]; then
        while IFS= read -r plist; do
            [[ -z "$plist" ]] && continue
            (( total_count++ ))
            local fname="${plist##*/}"
            prog=$(_get_plist_program "$plist")

            # Check for suspicious behaviors: executing from /tmp, /var/tmp, curl, nc, raw bash -c
            local is_suspicious=0
            local reason=""

            if [[ "$prog" =~ ^/tmp || "$prog" =~ ^/var/tmp || "$prog" =~ ^/private/tmp ]]; then
                is_suspicious=1
                reason="executes from temp directory ($prog)"
            elif grep -qiE '(curl|nc[[:space:]]|socat|bash -c|sh -c|python -c|osascript -e)' "$plist" 2>/dev/null; then
                is_suspicious=1
                reason="contains inline shell/network script execution"
            elif [[ "$fname" =~ ^(com\.local\.|ai\.hermes\.|pentest) ]] || [[ "$prog" =~ /Downloads/ ]]; then
                # Custom user persistence / dev gateway
                custom_list="${custom_list:+$custom_list; }${fname} ($prog)"
            fi

            if (( is_suspicious == 1 )); then
                suspicious_list="${suspicious_list:+$suspicious_list; }${fname} (${reason})"
                fix_cmds="${fix_cmds:+$fix_cmds; }launchctl unload -w \"$plist\" 2>/dev/null; rm \"$plist\""
            fi
        done <<< "$(find "$user_agents_dir" -maxdepth 1 -name "*.plist" 2>/dev/null || true)"
    fi

    # 2. Inspect System LaunchAgents (/Library/LaunchAgents)
    if [[ -d "$sys_agents_dir" ]]; then
        while IFS= read -r plist; do
            [[ -z "$plist" ]] && continue
            (( total_count++ ))
            local fname="${plist##*/}"
            prog=$(_get_plist_program "$plist")

            if [[ "$prog" =~ ^/tmp || "$prog" =~ ^/var/tmp || "$prog" =~ ^/private/tmp ]]; then
                suspicious_list="${suspicious_list:+$suspicious_list; }${fname} (executes from temp directory)"
                fix_cmds="${fix_cmds:+$fix_cmds; }sudo launchctl unload -w \"$plist\" 2>/dev/null; sudo rm \"$plist\""
            fi
        done <<< "$(find "$sys_agents_dir" -maxdepth 1 -name "*.plist" 2>/dev/null || true)"
    fi

    if [[ -n "$suspicious_list" ]]; then
        res_status="WARN"
        details="Suspicious LaunchAgents detected: ${suspicious_list}"
        remediation="${fix_cmds}"
    elif [[ -n "$custom_list" ]]; then
        res_status="INFO"
        details="Reviewed ${total_count} LaunchAgents. Custom user agents noted: ${custom_list}"
        remediation="Review custom LaunchAgents in ~/Library/LaunchAgents/ if not recognized"
    else
        res_status="PASS"
        details="Inspected ${total_count} LaunchAgents across ~/Library and /Library; all point to standard binaries."
        remediation=""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# PERS-02: System LaunchDaemons Review
# Lists items in `/Library/LaunchDaemons`.
audit_launch_daemons() {
    local check_id="${1:-PERS-02}"
    local category="${2:-persistence}"
    local title="${3:-System LaunchDaemons Review}"
    local weight="${4:-7}"

    local res_status="PASS"
    local details=""
    local remediation=""

    local daemons_dir="/Library/LaunchDaemons"
    local total_count=0
    local suspicious_list=""
    local fix_cmds=""
    local plist=""
    local prog=""

    if [[ -d "$daemons_dir" ]]; then
        while IFS= read -r plist; do
            [[ -z "$plist" ]] && continue
            (( total_count++ ))
            local fname="${plist##*/}"
            prog=$(_get_plist_program "$plist")

            # Flag daemons executing from temporary paths or user directories
            if [[ "$prog" =~ ^/tmp || "$prog" =~ ^/var/tmp || "$prog" =~ ^/private/tmp ]]; then
                suspicious_list="${suspicious_list:+$suspicious_list; }${fname} (executes from temporary path: $prog)"
                fix_cmds="${fix_cmds:+$fix_cmds; }sudo launchctl unload -w \"$plist\" 2>/dev/null; sudo rm \"$plist\""
            elif [[ "$prog" =~ ^/Users/ ]]; then
                suspicious_list="${suspicious_list:+$suspicious_list; }${fname} (root daemon points to user home: $prog)"
                fix_cmds="${fix_cmds:+$fix_cmds; }sudo launchctl unload -w \"$plist\" 2>/dev/null; sudo rm \"$plist\""
            elif [[ -n "$prog" && ! -e "$prog" ]]; then
                suspicious_list="${suspicious_list:+$suspicious_list; }${fname} (missing binary target: $prog)"
                fix_cmds="${fix_cmds:+$fix_cmds; }sudo launchctl unload -w \"$plist\" 2>/dev/null; sudo rm \"$plist\""
            fi
        done <<< "$(find "$daemons_dir" -maxdepth 1 -name "*.plist" 2>/dev/null || true)"
    fi

    if [[ -n "$suspicious_list" ]]; then
        res_status="WARN"
        details="Suspicious or broken LaunchDaemons found: ${suspicious_list}"
        remediation="${fix_cmds}"
    else
        res_status="PASS"
        details="Inspected ${total_count} LaunchDaemons in /Library/LaunchDaemons; all reference valid system/application targets."
        remediation=""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# PERS-03: Scheduled Cron Jobs
# Checks `crontab -l` and `/etc/cron*`. INFO/WARN if active cron jobs exist.
audit_crontabs() {
    local check_id="${1:-PERS-03}"
    local category="${2:-persistence}"
    local title="${3:-Scheduled Cron Jobs}"
    local weight="${4:-5}"

    local res_status="PASS"
    local details=""
    local remediation=""

    local user_cron=""
    user_cron=$(crontab -l 2>/dev/null | grep -v '^[[:space:]]*#' | grep -v '^[[:space:]]*$' || true)

    local etc_cron_entries=""
    local cron_file=""

    # Check /etc/crontab
    if [[ -f /etc/crontab ]]; then
        local content
        content=$(grep -v '^[[:space:]]*#' /etc/crontab 2>/dev/null | grep -v '^[[:space:]]*$' || true)
        [[ -n "$content" ]] && etc_cron_entries="${etc_cron_entries:+$etc_cron_entries; }/etc/crontab"
    fi

    # Check /etc/cron.d, /etc/cron.daily, etc.
    for cdir in /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly; do
        if [[ -d "$cdir" ]]; then
            local fcount
            fcount=$(find "$cdir" -type f 2>/dev/null | wc -l | tr -d ' ')
            if (( fcount > 0 )); then
                etc_cron_entries="${etc_cron_entries:+$etc_cron_entries; }${cdir} (${fcount} jobs)"
            fi
        fi
    done

    if [[ -n "$user_cron" || -n "$etc_cron_entries" ]]; then
        res_status="WARN"
        local summary=""
        if [[ -n "$user_cron" ]]; then
            local lines
            lines=$(echo "$user_cron" | wc -l | tr -d ' ')
            summary="User crontab active (${lines} job(s))"
        fi
        if [[ -n "$etc_cron_entries" ]]; then
            summary="${summary:+$summary; }System cron entries found: ${etc_cron_entries}"
        fi
        details="${summary}. Legacy cron is deprecated on macOS and commonly abused for unmonitored persistence."
        remediation="Review scheduled tasks via 'crontab -l' and migrate to native launchd plists"
    else
        res_status="PASS"
        details="No active cron jobs configured (system relies exclusively on launchd)."
        remediation=""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# PERS-04: User Login Items
# Queries login items via `osascript` or `sfltool`.
audit_login_items() {
    local check_id="${1:-PERS-04}"
    local category="${2:-persistence}"
    local title="${3:-User Login Items}"
    local weight="${4:-4}"

    local res_status="PASS"
    local details=""
    local remediation=""

    local login_items=""
    login_items=$(osascript -e 'tell application "System Events" to get name of every login item' 2>/dev/null || true)

    # Fallback to sfltool if osascript returned empty
    if [[ -z "$login_items" ]] && command -v sfltool >/dev/null 2>&1; then
        login_items=$(sfltool dumpbtm 2>/dev/null | grep -E '^[[:space:]]+Name:' | sed 's/^[[:space:]]*Name:[[:space:]]*//' | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g' || true)
    fi

    if [[ -n "$login_items" ]]; then
        res_status="INFO"
        details="Configured user login items: ${login_items}"
        remediation="Review login items in System Settings > General > Login Items & Extensions"
    else
        res_status="PASS"
        details="No user login items configured to launch at desktop session logon."
        remediation=""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# PERS-05: SSH Authorized Keys
# Checks `~/.ssh/authorized_keys`. INFO/WARN if keys are present (review authorized public keys), PASS if clean/absent.
audit_authorized_keys() {
    local check_id="${1:-PERS-05}"
    local category="${2:-persistence}"
    local title="${3:-SSH Authorized Public Keys}"
    local weight="${4:-6}"

    local res_status="PASS"
    local details=""
    local remediation=""

    local auth_file="$HOME/.ssh/authorized_keys"
    local auth_file2="$HOME/.ssh/authorized_keys2"

    local active_keys=""
    local key_count=0

    for f in "$auth_file" "$auth_file2"; do
        if [[ -f "$f" ]]; then
            local valid_keys
            valid_keys=$(grep -v '^[[:space:]]*#' "$f" 2>/dev/null | grep -v '^[[:space:]]*$' || true)
            if [[ -n "$valid_keys" ]]; then
                local count
                count=$(echo "$valid_keys" | wc -l | tr -d ' ')
                (( key_count += count ))
                active_keys="${active_keys:+$active_keys, }${f##*/} (${count} key(s))"
            fi
        fi
    done

    if (( key_count > 0 )); then
        res_status="INFO"
        details="${key_count} authorized public key(s) installed (${active_keys}). Ensure all keys belong to verified administrative entities."
        remediation="Audit public keys in ~/.ssh/authorized_keys and revoke unneeded or obsolete entries"
    else
        res_status="PASS"
        details="No ~/.ssh/authorized_keys file present (inbound SSH public-key logins disabled for current user)."
        remediation=""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# PERS-06: Sudoers Configuration & NOPASSWD Rules
# Checks `/etc/sudoers.d/` for NOPASSWD or custom rule additions.
audit_sudoers() {
    local check_id="${1:-PERS-06}"
    local category="${2:-persistence}"
    local title="${3:-Sudoers Configuration & NOPASSWD Rules}"
    local weight="${4:-8}"

    local res_status="PASS"
    local details=""
    local remediation=""

    local sudoers_d="/etc/sudoers.d"
    local custom_files=""
    local nopasswd_matches=""

    # Check for custom files in /etc/sudoers.d/
    if [[ -d "$sudoers_d" ]]; then
        while IFS= read -r sfile; do
            [[ -z "$sfile" ]] && continue
            local fname="${sfile##*/}"
            [[ "$fname" =~ ^\. || "$fname" =~ ~$ ]] && continue
            custom_files="${custom_files:+$custom_files, }${fname}"

            # Check for NOPASSWD directive
            if grep -qiE '^[[:space:]]*[^#].*NOPASSWD:' "$sfile" 2>/dev/null; then
                nopasswd_matches="${nopasswd_matches:+$nopasswd_matches; }${fname}"
            fi
        done <<< "$(find "$sudoers_d" -maxdepth 1 -type f 2>/dev/null || true)"
    fi

    # Also check /etc/sudoers for NOPASSWD if readable
    if [[ -r /etc/sudoers ]]; then
        if grep -qiE '^[[:space:]]*[^#].*NOPASSWD:' /etc/sudoers 2>/dev/null; then
            nopasswd_matches="${nopasswd_matches:+$nopasswd_matches; }/etc/sudoers"
        fi
    fi

    if [[ -n "$nopasswd_matches" ]]; then
        res_status="FAIL"
        details="Passwordless privilege escalation (NOPASSWD) detected in: ${nopasswd_matches}"
        remediation="Remove NOPASSWD directives from /etc/sudoers and /etc/sudoers.d/ using 'sudo visudo'"
    elif [[ -n "$custom_files" ]]; then
        res_status="INFO"
        details="Custom sudoers configuration files present in /etc/sudoers.d/: ${custom_files} (no NOPASSWD found)."
        remediation=""
    else
        res_status="PASS"
        details="No custom sudoers files or passwordless NOPASSWD directives detected in /etc/sudoers.d/."
        remediation=""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# PERS-07: Privileged Helper Tools
# Lists files in `/Library/PrivilegedHelperTools` and verifies code signatures.
# Never deletes helpers; unsigned/invalid signatures are reported for review.
audit_privileged_helpers() {
    local check_id="${1:-PERS-07}"
    local category="${2:-persistence}"
    local title="${3:-Privileged Helper Tools}"
    local weight="${4:-6}"

    local res_status="PASS"
    local details=""
    local remediation=""

    local helper_dir="/Library/PrivilegedHelperTools"
    local helper_count=0
    local unsigned_list=""
    local helper_names=""
    local preview_limit=5
    local file=""
    local fname=""
    local can_codesign=0

    if command -v codesign >/dev/null 2>&1; then
        can_codesign=1
    fi

    if [[ -d "$helper_dir" ]]; then
        while IFS= read -r file; do
            [[ -z "$file" ]] && continue
            (( helper_count++ ))
            fname="${file##*/}"
            if (( helper_count <= preview_limit )); then
                helper_names="${helper_names:+$helper_names, }${fname}"
            fi

            if (( can_codesign == 1 )); then
                if ! codesign -v --verify "$file" 2>/dev/null; then
                    unsigned_list="${unsigned_list:+$unsigned_list, }${fname}"
                fi
            fi
        done <<< "$(find "$helper_dir" -maxdepth 1 -type f 2>/dev/null || true)"
    fi

    if (( helper_count == 0 )); then
        res_status="PASS"
        details="No privileged helper tools installed."
        remediation=""
    elif [[ -n "$unsigned_list" ]]; then
        res_status="WARN"
        details="Unsigned or invalid-signature privileged helper(s): ${unsigned_list}"
        remediation="Review unsigned privileged helpers with 'codesign -dv --verbose=2 <path>'. Remove only after confirming they are unexpected. Do not blindly delete."
    elif (( can_codesign == 1 )); then
        res_status="INFO"
        details="Reviewed ${helper_count} privileged helper tool(s); all signatures verified"
        if [[ -n "$helper_names" ]]; then
            if (( helper_count > preview_limit )); then
                details="${details} (${helper_names}, ...)"
            else
                details="${details} (${helper_names})"
            fi
        fi
        remediation=""
    else
        res_status="INFO"
        details="Reviewed ${helper_count} privileged helper tool(s); codesign unavailable to verify signatures"
        if [[ -n "$helper_names" ]]; then
            if (( helper_count > preview_limit )); then
                details="${details} (${helper_names}, ...)"
            else
                details="${details} (${helper_names})"
            fi
        fi
        remediation=""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# PERS-08: Printer Sharing
# Uses cupsctl when present. WARN if printers are shared; PASS if CUPS is not
# sharing, or if cupsctl is missing and there is no evidence of sharing.
audit_printer_sharing() {
    local check_id="${1:-PERS-08}"
    local category="${2:-persistence}"
    local title="${3:-Printer Sharing}"
    local weight="${4:-5}"

    local res_status="PASS"
    local details=""
    local remediation=""

    local cupsctl_bin=""
    local cups_out=""
    local sharing_on=0
    local evidence=""

    if command -v cupsctl >/dev/null 2>&1; then
        cupsctl_bin=$(command -v cupsctl)
    elif [[ -x /usr/sbin/cupsctl ]]; then
        cupsctl_bin="/usr/sbin/cupsctl"
    fi

    if [[ -n "$cupsctl_bin" ]]; then
        cups_out=$("$cupsctl_bin" 2>/dev/null || true)
        if echo "$cups_out" | grep -qE '_share_printers=1([^0-9]|$)'; then
            sharing_on=1
            evidence="_share_printers=1"
        elif echo "$cups_out" | grep -qiE 'SharePrinters[[:space:]]*[=:]?[[:space:]]*Yes'; then
            sharing_on=1
            evidence="SharePrinters Yes"
        elif launchctl list org.cups.cupsd >/dev/null 2>&1 \
            && echo "$cups_out" | grep -qiE '(^|[[:space:]])Browsing[[:space:]]*[=:][[:space:]]*(On|Yes|1)([^A-Za-z0-9]|$)'; then
            sharing_on=1
            evidence="org.cups.cupsd loaded with browsing enabled"
        fi
    fi

    if (( sharing_on == 1 )); then
        res_status="WARN"
        details="Printer Sharing is enabled (${evidence}). Shared printers increase the local attack surface via CUPS."
        remediation="cupsctl --no-share-printers; or System Settings > General > Sharing > Printer Sharing off"
    else
        res_status="PASS"
        if [[ -z "$cupsctl_bin" ]]; then
            details="cupsctl not found; no evidence of printer sharing."
        else
            details="Printer Sharing is disabled (CUPS is not sharing printers)."
        fi
        remediation=""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# Aliases for ID-based execution
audit_pers_01() { audit_launch_agents "$@"; }
audit_pers_02() { audit_launch_daemons "$@"; }
audit_pers_03() { audit_crontabs "$@"; }
audit_pers_04() { audit_login_items "$@"; }
audit_pers_05() { audit_authorized_keys "$@"; }
audit_pers_06() { audit_sudoers "$@"; }
audit_pers_07() { audit_privileged_helpers "$@"; }
audit_pers_08() { audit_printer_sharing "$@"; }

# Category Runner
run_audit_persistence() {
    audit_launch_agents
    audit_launch_daemons
    audit_crontabs
    audit_login_items
    audit_authorized_keys
    audit_sudoers
    audit_privileged_helpers
    audit_printer_sharing
}

# Auto-registration with engine.sh
register_persistence_checks() {
    if command -v register_check >/dev/null 2>&1 || typeset -f register_check >/dev/null 2>&1; then
        register_check "PERS-01" "persistence" "LaunchAgents Persistence Review" 7 audit_launch_agents
        register_check "PERS-02" "persistence" "System LaunchDaemons Review" 7 audit_launch_daemons
        register_check "PERS-03" "persistence" "Scheduled Cron Jobs" 5 audit_crontabs
        register_check "PERS-04" "persistence" "User Login Items" 4 audit_login_items
        register_check "PERS-05" "persistence" "SSH Authorized Public Keys" 6 audit_authorized_keys
        register_check "PERS-06" "persistence" "Sudoers Configuration & NOPASSWD Rules" 8 audit_sudoers
        register_check "PERS-07" "persistence" "Privileged Helper Tools" 6 audit_privileged_helpers
        register_check "PERS-08" "persistence" "Printer Sharing" 5 audit_printer_sharing
    fi
}

register_persistence_checks
