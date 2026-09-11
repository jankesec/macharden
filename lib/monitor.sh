#!/bin/zsh
# ==============================================================================
# macharden - lib/monitor.sh
# Continuous background monitoring, LaunchAgent lifecycle management,
# and macOS native alerting engine.
# ==============================================================================

# Ensure execution under /bin/zsh
if [ -z "$ZSH_VERSION" ]; then
    exec /bin/zsh "$0" "$@"
fi

# Fallback UI helpers if ui.sh is not already loaded
if ! typeset -f ui_info >/dev/null 2>&1; then
    ui_info() { printf "\033[36m[INFO]\033[0m %s\n" "$1"; }
    ui_warn() { printf "\033[33m[WARN]\033[0m %s\n" "$1"; }
    ui_error() { printf "\033[31m[ERROR]\033[0m %s\n" "$1" >&2; }
    ui_success() { printf "\033[32m[PASS]\033[0m %s\n" "$1"; }
    ui_section() { printf "\n\033[1;36m▶ %s\033[0m\n----------------------------------------------------------------------\n" "$1"; }
fi

# Resolve library and project base directories
MONITOR_SCRIPT_PATH="${(%):-%x}" 2>/dev/null || MONITOR_SCRIPT_PATH="$0"
MONITOR_LIB_DIR="$(cd "$(dirname "$MONITOR_SCRIPT_PATH")" && pwd)"
MONITOR_BASE_DIR="$(cd "$MONITOR_LIB_DIR/.." && pwd)"

# Configuration constants
MACHAR_DAEMON_LABEL="com.macharden.daemon"
MACHAR_DEFAULT_SCHEDULE="weekly"

# Helper to resolve LaunchAgents directory (supports MACHAR_LAUNCHAGENTS_DIR for sandbox testing)
get_launch_agents_dir() {
    echo "${MACHAR_LAUNCHAGENTS_DIR:-$HOME/Library/LaunchAgents}"
}

# Helper to resolve logs directory (supports MACHAR_LOG_DIR for testing)
get_logs_dir() {
    echo "${MACHAR_LOG_DIR:-$HOME/.macharden/logs}"
}

# Helper to resolve target LaunchAgent plist path
get_target_plist() {
    local dir
    dir="$(get_launch_agents_dir)"
    echo "$dir/${MACHAR_DAEMON_LABEL}.plist"
}

# Helper to resolve macharden binary path
get_machar_bin() {
    if [[ -n "${MACHAR_BIN_PATH:-}" && -x "$MACHAR_BIN_PATH" ]]; then
        echo "$MACHAR_BIN_PATH"
    elif [[ -x "$MONITOR_BASE_DIR/bin/macharden" ]]; then
        echo "$MONITOR_BASE_DIR/bin/macharden"
    elif command -v macharden >/dev/null 2>&1; then
        command -v macharden
    else
        echo "/usr/local/bin/macharden"
    fi
}

# ------------------------------------------------------------------------------
# Function: daemon_install [schedule]
# Installs and loads the LaunchAgent plist to ~/Library/LaunchAgents/
# with user-specified interval (hourly, daily, weekly, monthly, on-login, or seconds).
# ------------------------------------------------------------------------------
daemon_install() {
    local schedule="${1:-$MACHAR_DEFAULT_SCHEDULE}"
    schedule="${schedule:l}"

    local launch_agents_dir="$(get_launch_agents_dir)"
    local log_dir="$(get_logs_dir)"
    local target_plist="$(get_target_plist)"
    local machar_bin="$(get_machar_bin)"
    local template_plist="$MONITOR_BASE_DIR/launchd/${MACHAR_DAEMON_LABEL}.plist"

    # Validate schedule option and calculate interval
    local interval_seconds=0
    local is_run_at_load=0
    local schedule_desc=""

    case "$schedule" in
        hourly)
            interval_seconds=3600
            schedule_desc="Hourly (every 3,600 seconds)"
            ;;
        daily)
            interval_seconds=86400
            schedule_desc="Daily (every 86,400 seconds / 24 hours)"
            ;;
        weekly|"")
            interval_seconds=604800
            schedule_desc="Weekly (every 604,800 seconds / 7 days)"
            ;;
        monthly)
            interval_seconds=2592000
            schedule_desc="Monthly (every 2,592,000 seconds / 30 days)"
            ;;
        login|on-login|boot|load)
            is_run_at_load=1
            schedule_desc="On user login (RunAtLoad)"
            ;;
        *)
            if [[ "$schedule" =~ ^[0-9]+$ ]] && (( schedule > 0 )); then
                interval_seconds=$schedule
                schedule_desc="Custom interval (${schedule} seconds)"
            else
                ui_error "Invalid schedule: '$schedule'"
                echo "Supported schedules: hourly, daily, weekly, monthly, on-login, or interval in seconds." >&2
                return 1
            fi
            ;;
    esac

    # Ensure LaunchAgents directory exists safely
    if [[ ! -d "$launch_agents_dir" ]]; then
        mkdir -p "$launch_agents_dir" 2>/dev/null || {
            ui_error "Failed to create LaunchAgents directory: $launch_agents_dir"
            return 1
        }
    fi

    # Ensure log directory exists with secure permissions
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir" 2>/dev/null || {
            ui_error "Failed to create log directory: $log_dir"
            return 1
        }
        chmod 700 "${log_dir:h}" 2>/dev/null || true
        chmod 700 "$log_dir" 2>/dev/null || true
    fi

    # Safety: backup existing plist if already present
    if [[ -f "$target_plist" ]]; then
        local backup_path="${target_plist}.bak"
        cp -f "$target_plist" "$backup_path" 2>/dev/null || true
        ui_info "Existing LaunchAgent backed up to: ${backup_path}"
    fi

    # Unload currently registered service if loaded in launchd
    local uid_val="$(id -u 2>/dev/null || echo 501)"
    if launchctl list 2>/dev/null | grep -q "${MACHAR_DAEMON_LABEL}"; then
        launchctl bootout "gui/${uid_val}/${MACHAR_DAEMON_LABEL}" 2>/dev/null || \
        launchctl bootout "gui/${uid_val}" "$target_plist" 2>/dev/null || \
        launchctl unload -w "$target_plist" 2>/dev/null || true
    fi

    # Prepare schedule XML snippet
    local schedule_xml=""
    if (( is_run_at_load )); then
        schedule_xml="    <key>RunAtLoad</key>
    <true/>"
    else
        schedule_xml="    <key>StartInterval</key>
    <integer>${interval_seconds}</integer>"
    fi

    # Load plist template
    local plist_content=""
    if [[ -f "$template_plist" ]]; then
        plist_content="$(cat "$template_plist")"
    else
        # Built-in robust template if file was missing
        plist_content="<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
    <key>Label</key>
    <string>${MACHAR_DAEMON_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>__MACHAR_BIN__</string>
        <string>--alert</string>
        <string>-q</string>
        <string>-f</string>
        <string>term</string>
        <string>-o</string>
        <string>~/.macharden/logs/audit.log</string>
    </array>
    <key>ProcessType</key>
    <string>Background</string>
    <key>LowPriorityIO</key>
    <true/>
    <key>Nice</key>
    <integer>10</integer>
    <key>StandardOutPath</key>
    <string>~/.macharden/logs/macharden.stdout.log</string>
    <key>StandardErrorPath</key>
    <string>~/.macharden/logs/macharden.stderr.log</string>
    <key>StartInterval</key>
    <integer>604800</integer>
</dict>
</plist>"
    fi

    # Expand placeholders and paths for launchd compatibility
    # launchd does not expand tilde (~), so paths must be absolute
    plist_content="${plist_content//__MACHAR_BIN__/$machar_bin}"
    plist_content="${plist_content//\/usr\/local\/bin\/macharden/$machar_bin}"
    plist_content="${plist_content//\~\/\.macharden\/logs/$log_dir}"
    plist_content="${plist_content//__LOG_DIR__/$log_dir}"

    # Replace schedule section in plist
    if echo "$plist_content" | grep -q "<key>StartInterval</key>"; then
        plist_content="$(echo "$plist_content" | perl -0777 -pe "s|<key>StartInterval</key>\s*<integer>\d+</integer>|$schedule_xml|s")"
    elif echo "$plist_content" | grep -q "<key>RunAtLoad</key>"; then
        plist_content="$(echo "$plist_content" | perl -0777 -pe "s|<key>RunAtLoad</key>\s*<(true\|false)/>|$schedule_xml|s")"
    else
        plist_content="${plist_content/<\/dict>/$schedule_xml
<\/dict>}"
    fi

    # Write out target plist file
    printf "%s\n" "$plist_content" > "$target_plist" || {
        ui_error "Failed to write LaunchAgent plist to: $target_plist"
        return 1
    }

    # Set secure permissions (644 is required by launchd)
    chmod 644 "$target_plist"

    # Validate syntax with plutil if available
    if command -v plutil >/dev/null 2>&1; then
        if ! plutil -lint "$target_plist" >/dev/null 2>&1; then
            ui_error "Generated LaunchAgent plist failed plutil XML validation."
            [[ -f "${target_plist}.bak" ]] && mv -f "${target_plist}.bak" "$target_plist"
            return 1
        fi
    fi

    # Load LaunchAgent with launchctl
    local loaded=0
    if launchctl bootstrap "gui/${uid_val}" "$target_plist" 2>/dev/null; then
        loaded=1
    elif launchctl load -w "$target_plist" 2>/dev/null; then
        loaded=1
    fi

    ui_success "macharden background daemon successfully installed."
    ui_info "Schedule:        $schedule_desc"
    ui_info "Service Plist:   $target_plist"
    ui_info "Logs Directory:  $log_dir"
    ui_info "Binary:          $machar_bin"

    if (( loaded )); then
        ui_info "Launchd State:   Loaded & Active"
    else
        ui_warn "LaunchAgent written, but launchctl load not permitted in current shell session (will activate on next login)."
    fi

    return 0
}

# ------------------------------------------------------------------------------
# Function: daemon_uninstall
# Unloads and removes the LaunchAgent plist from ~/Library/LaunchAgents/.
# ------------------------------------------------------------------------------
daemon_uninstall() {
    local target_plist="$(get_target_plist)"
    local uid_val="$(id -u 2>/dev/null || echo 501)"
    local removed=0

    # Unload from launchd
    if launchctl list 2>/dev/null | grep -q "${MACHAR_DAEMON_LABEL}"; then
        removed=1
        launchctl bootout "gui/${uid_val}/${MACHAR_DAEMON_LABEL}" 2>/dev/null || \
        launchctl bootout "gui/${uid_val}" "$target_plist" 2>/dev/null || \
        launchctl unload -w "$target_plist" 2>/dev/null || true
    fi

    # Remove plist file
    if [[ -f "$target_plist" ]]; then
        removed=1
        rm -f "$target_plist"
    fi

    # Remove backup if present
    if [[ -f "${target_plist}.bak" ]]; then
        rm -f "${target_plist}.bak"
    fi

    if (( removed )); then
        ui_success "macharden background daemon uninstalled successfully."
        ui_info "Removed: $target_plist"
        ui_info "Note: Past audit logs in $(get_logs_dir) have been preserved."
    else
        ui_info "macharden daemon is not currently installed or loaded."
    fi

    return 0
}

# ------------------------------------------------------------------------------
# Function: daemon_status
# Checks whether the background scan agent is loaded, running, and reports logs.
# ------------------------------------------------------------------------------
daemon_status() {
    local target_plist="$(get_target_plist)"
    local log_dir="$(get_logs_dir)"

    ui_section "macharden Background Daemon Status"

    local is_installed=0
    local is_loaded=0
    local is_running=0
    local current_pid="-"
    local last_exit="0"
    local schedule_info="Unknown"

    # 1. Check plist file installation
    if [[ -f "$target_plist" ]]; then
        is_installed=1
        if grep -q "<key>RunAtLoad</key>" "$target_plist"; then
            schedule_info="On login (RunAtLoad)"
        elif grep -q "<key>StartInterval</key>" "$target_plist"; then
            local interval
            interval=$(grep -A 1 "<key>StartInterval</key>" "$target_plist" | grep "<integer>" | sed -E 's/.*<integer>([0-9]+)<\/integer>.*/\1/' | tr -d '[:space:]')
            if [[ -n "$interval" ]]; then
                case "$interval" in
                    3600) schedule_info="Hourly (every 3,600s)" ;;
                    86400) schedule_info="Daily (every 86,400s)" ;;
                    604800) schedule_info="Weekly (every 604,800s)" ;;
                    2592000) schedule_info="Monthly (every 2,592,000s)" ;;
                    *) schedule_info="Every ${interval} seconds" ;;
                esac
            fi
        fi
    fi

    # 2. Check launchctl status
    local l_entry
    l_entry="$(launchctl list 2>/dev/null | grep -E "[[:space:]]${MACHAR_DAEMON_LABEL}$" || true)"
    if [[ -n "$l_entry" ]]; then
        is_loaded=1
        current_pid="$(echo "$l_entry" | awk '{print $1}')"
        last_exit="$(echo "$l_entry" | awk '{print $2}')"
        if [[ "$current_pid" != "-" && "$current_pid" =~ ^[0-9]+$ ]]; then
            is_running=1
        fi
    fi

    # Print summary rows
    printf "  %-22s %s\n" "Service Identifier:" "$MACHAR_DAEMON_LABEL"

    if (( is_installed )); then
        printf "  %-22s \033[32mInstalled\033[0m (%s)\n" "LaunchAgent Plist:" "$target_plist"
        printf "  %-22s %s\n" "Configured Schedule:" "$schedule_info"
    else
        printf "  %-22s \033[33mNot Installed\033[0m (%s)\n" "LaunchAgent Plist:" "$target_plist"
    fi

    if (( is_running )); then
        printf "  %-22s \033[32mActive / Running\033[0m (PID: %s)\n" "Launchd Status:" "$current_pid"
    elif (( is_loaded )); then
        printf "  %-22s \033[36mLoaded (Idle / Scheduled)\033[0m (Last exit: %s)\n" "Launchd Status:" "$last_exit"
    else
        printf "  %-22s \033[31mNot Loaded\033[0m\n" "Launchd Status:"
    fi

    printf "  %-22s %s\n" "Logs Directory:" "$log_dir"

    # 3. Inspect logs and previous scan history
    local audit_log="$log_dir/audit.log"
    local stdout_log="$log_dir/macharden.stdout.log"
    local stderr_log="$log_dir/macharden.stderr.log"

    if [[ -f "$audit_log" ]]; then
        local log_time
        log_time="$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$audit_log" 2>/dev/null || echo "Unknown")"
        printf "  %-22s %s\n" "Last Audit Run:" "$log_time"

        local score_line
        score_line="$(grep -E "(Hardening Index|CRITICAL|EXCELLENT|GOOD|FAIR)" "$audit_log" 2>/dev/null | tail -n 1 || true)"
        if [[ -n "$score_line" ]]; then
            local clean_score="$(echo "$score_line" | sed -E $'s/\x1B\\[[0-9;]*[a-zA-Z]//g' | sed -E 's/^[[:space:]]+//')"
            printf "  %-22s %s\n" "Last Recorded Score:" "$clean_score"
        fi
    elif [[ -f "$stdout_log" ]]; then
        local out_time
        out_time="$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$stdout_log" 2>/dev/null || echo "Unknown")"
        printf "  %-22s %s\n" "Last Execution Log:" "$out_time"
    else
        printf "  %-22s No previous background scan logs found\n" "Audit History:"
    fi

    # Return status
    if (( is_installed && is_loaded )); then
        return 0
    elif (( is_installed )); then
        return 0
    else
        return 1
    fi
}

# ------------------------------------------------------------------------------
# Function: send_alert <score> <failures_count> [--force]
# Triggers a native macOS notification (osascript) if critical hardening issues
# or secrets leaks are found during automated runs.
# ------------------------------------------------------------------------------
send_alert() {
    local score="${1:-${HARDENING_INDEX:-100.0}}"
    local failures="${2:-${COUNT_FAIL:-0}}"
    local opt_force=0

    if [[ "${3:-}" == "--force" || "${1:-}" == "--force" ]]; then
        opt_force=1
    fi

    # Normalize numeric score value
    local score_num=100.0
    if [[ "$score" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        score_num="$score"
    elif [[ "$score" =~ [0-9]+ ]]; then
        score_num="${score%%.*}"
    fi

    # Check for secrets leaks or critical failures in global engine state if failures > 0
    local has_secrets_leak=0
    local has_critical_fail=0
    local leak_details=""
    local critical_titles=()
    local num_results=${#RES_IDS[@]}

    if (( failures > 0 && num_results > 0 )); then
        for (( i = 1; i <= num_results; i++ )); do
            local st="${RES_STATUSES[i]}"
            if [[ "$st" == "FAIL" ]]; then
                local cat="${RES_CATEGORIES[i]:l}"
                local cid="${RES_IDS[i]:u}"
                local title="${RES_TITLES[i]}"
                local weight="${RES_WEIGHTS[i]:-5}"
                [[ "$weight" =~ ^[0-9]+ ]] || weight=5

                if [[ "$cat" == "secrets" ]] || [[ "$cid" =~ ^SEC- ]]; then
                    has_secrets_leak=1
                    leak_details="${leak_details:+$leak_details, }$title"
                fi

                if (( weight >= 8 )) || [[ "$cid" == "HARD-01" || "$cid" == "HARD-02" ]]; then
                    has_critical_fail=1
                    critical_titles+=("$title")
                fi
            fi
        done
    fi

    # Determine whether alert condition is met:
    # 1. Any secrets leaks detected
    # 2. Critical high-weight hardening failures detected
    # 3. Overall failures count > 0
    # 4. Hardening index score < 70.0%
    # 5. Explicitly forced with --force
    local should_alert=0
    if (( has_secrets_leak )) || (( has_critical_fail )) || (( failures > 0 )) || (( score_num < 70.0 )) || (( opt_force )); then
        should_alert=1
    fi

    if (( ! should_alert )); then
        ui_info "macharden audit clean (Score: ${score}%, ${failures} failures). Notification alert suppressed."
        return 0
    fi

    # Compose notification text
    local notif_title="macharden Security Alert"
    local notif_subtitle=""
    local notif_message=""
    local sound_name="Basso"

    if (( has_secrets_leak )); then
        notif_subtitle="CRITICAL: Exposed Secrets Detected! (Score: ${score}%)"
        if [[ -n "$leak_details" ]]; then
            notif_message="Found secrets in: ${leak_details}. Run 'macharden -c secrets' immediately."
        else
            notif_message="Unencrypted API tokens or secrets detected in shell/environment files."
        fi
        sound_name="Basso"
    elif (( has_critical_fail )); then
        notif_subtitle="CRITICAL: High-Risk OS Controls Failed (Score: ${score}%)"
        if (( ${#critical_titles[@]} > 0 )); then
            notif_message="Failed: ${critical_titles[1]}${critical_titles[2]:+, ${critical_titles[2]}}. Run 'macharden --fix' to remediate."
        else
            notif_message="${failures} critical security control(s) failed on $(hostname -s)."
        fi
        sound_name="Basso"
    elif (( failures > 0 )); then
        notif_subtitle="Security Warning: ${failures} Check(s) Failed (Score: ${score}%)"
        notif_message="Background audit identified ${failures} security failures. Run 'macharden' to review."
        sound_name="Sosumi"
    elif (( opt_force )); then
        notif_title="macharden Monitor Status"
        notif_subtitle="Hardening Index: ${score}% (All Checks Passing)"
        notif_message="Continuous security monitoring is active on $(hostname -s)."
        sound_name="Hero"
    fi

    # Safely escape quotes and backslashes for AppleScript
    local safe_title="${notif_title//\\/\\\\}"
    safe_title="${safe_title//\"/\\\"}"
    local safe_subtitle="${notif_subtitle//\\/\\\\}"
    safe_subtitle="${safe_subtitle//\"/\\\"}"
    local safe_message="${notif_message//\\/\\\\}"
    safe_message="${safe_message//\"/\\\"}"

    # Trigger macOS native notification via osascript
    local osa_cmd="display notification \"$safe_message\" with title \"$safe_title\" subtitle \"$safe_subtitle\" sound name \"$sound_name\""

    local sent=0
    if command -v osascript >/dev/null 2>&1; then
        if osascript -e "$osa_cmd" 2>/dev/null; then
            sent=1
        fi
    fi

    if (( sent )); then
        ui_warn "macOS desktop notification alert sent: $notif_subtitle"
    else
        ui_warn "[ALERT NOTIFICATION] $notif_title - $notif_subtitle: $notif_message"
    fi

    return 0
}

# Standalone CLI execution dispatching (only runs when executed directly, not when sourced)
if [[ "$ZSH_EVAL_CONTEXT" != *":file"* ]]; then
    case "${1:-status}" in
        install)
            daemon_install "${2:-}"
            ;;
        uninstall)
            daemon_uninstall
            ;;
        status)
            daemon_status
            ;;
        alert)
            send_alert "${2:-100.0}" "${3:-0}" "${4:-}"
            ;;
        *)
            echo "Usage: $0 {install [schedule]|uninstall|status|alert [score] [failures]}" >&2
            exit 1
            ;;
    esac
fi
