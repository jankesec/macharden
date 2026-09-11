#!/bin/zsh
# ==============================================================================
# macharden - lib/audit_network.sh
# Network Security Audit Module: Application Firewall, Stealth Mode,
# Firewall Exceptions, BPF Sniffing, Hosts File Integrity, Wildcard Listeners
# ==============================================================================

# Ensure record_result fallback exists if sourced standalone
if ! command -v record_result >/dev/null 2>&1 && ! typeset -f record_result >/dev/null 2>&1; then
    record_result() {
        printf "[%s] %s (%s): %s - %s\n" "$4" "$1" "$2" "$3" "$6"
    }
fi

# NET-01: Application Firewall Status
# Checks `/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate`.
# PASS if enabled, FAIL if disabled.
audit_firewall() {
    local check_id="${1:-NET-01}"
    local category="${2:-network}"
    local title="${3:-Application Firewall Status}"
    local weight="${4:-9}"

    local res_status="FAIL"
    local details=""
    local remediation=""

    local fw_bin="/usr/libexec/ApplicationFirewall/socketfilterfw"
    local fw_out=""

    if [[ -x "$fw_bin" ]]; then
        fw_out=$("$fw_bin" --getglobalstate 2>&1)
    else
        fw_out=$(defaults read /Library/Preferences/com.apple.alf globalstate 2>/dev/null || echo "0")
    fi

    if echo "$fw_out" | grep -qiE "Firewall is enabled|State = 1|State = 2"; then
        res_status="PASS"
        details="macOS Application Firewall (ALF) is enabled and monitoring incoming connections."
        remediation=""
    else
        res_status="FAIL"
        details="macOS Application Firewall is disabled! The system does not filter uninvited inbound connections."
        remediation="sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on"
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# NET-02: Firewall Stealth Mode
# Checks `socketfilterfw --getstealthmode`.
# PASS if on, WARN/SUGG if off (recommend `--setstealthmode on`).
audit_firewall_stealth() {
    local check_id="${1:-NET-02}"
    local category="${2:-network}"
    local title="${3:-Firewall Stealth Mode}"
    local weight="${4:-5}"

    local res_status="SUGG"
    local details=""
    local remediation=""

    local fw_bin="/usr/libexec/ApplicationFirewall/socketfilterfw"
    local stealth_out=""

    if [[ -x "$fw_bin" ]]; then
        stealth_out=$("$fw_bin" --getstealthmode 2>&1)
    else
        local stealth_val
        stealth_val=$(defaults read /Library/Preferences/com.apple.alf stealthenabled 2>/dev/null || echo "0")
        [[ "$stealth_val" == "1" ]] && stealth_out="stealth mode is on"
    fi

    if echo "$stealth_out" | grep -qiE "stealth mode is on|enabled"; then
        res_status="PASS"
        details="Firewall Stealth Mode is enabled. System ignores ICMP echo requests and uninvited probe packets."
        remediation=""
    else
        res_status="SUGG"
        details="Firewall Stealth Mode is off. The host responds to ICMP pings and port discovery scans."
        remediation="sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on"
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# NET-03: Firewall Permissive Interpreters
# Checks `socketfilterfw --listapps` for overly permissive interpreters or tools
# (`python`, `ruby`, `socat`, `perl`, `node`, `bash`). WARN/FAIL if interpreters are allowed incoming connections.
audit_firewall_exceptions() {
    local check_id="${1:-NET-03}"
    local category="${2:-network}"
    local title="${3:-Firewall Permissive Exceptions}"
    local weight="${4:-8}"

    local res_status="PASS"
    local details=""
    local remediation=""

    local fw_bin="/usr/libexec/ApplicationFirewall/socketfilterfw"
    local apps_out=""

    if [[ -x "$fw_bin" ]]; then
        apps_out=$("$fw_bin" --listapps 2>&1)
    fi

    if [[ -z "$apps_out" ]]; then
        res_status="PASS"
        details="No custom application firewall rules found or socketfilterfw unavailable."
        record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
        return 0
    fi

    # Parse allowed incoming applications matching dangerous interpreters
    local flagged_apps
    flagged_apps=$(echo "$apps_out" | awk '
    /^[0-9]+[[:space:]]*:/ {
        sub(/^[0-9]+[[:space:]]*:[[:space:]]*/, "")
        gsub(/[[:space:]]+$/, "")
        current_app=$0
    }
    /Allow incoming connections/ {
        low = tolower(current_app)
        if (low ~ /(\/|^)(python[0-9._-]*|ruby|socat|perl|node|bash|zsh|nc|ncat)(\.app|\/|$)/ ||
            low ~ /\/(python|ruby|socat|perl|node|bash|zsh)(\.app)?$/) {
            print current_app
        }
    }')

    if [[ -n "$flagged_apps" ]]; then
        res_status="WARN"
        local app_count
        app_count=$(echo "$flagged_apps" | wc -l | tr -d ' ')
        local app_summary
        app_summary=$(echo "$flagged_apps" | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
        details="Dangerous interpreters/tools allowed incoming connections (${app_count}): ${app_summary}"

        # Generate block commands for remediation
        local block_cmds=""
        while IFS= read -r app_path; do
            [[ -z "$app_path" ]] && continue
            block_cmds="${block_cmds:+$block_cmds; }sudo /usr/libexec/ApplicationFirewall/socketfilterfw --blockapp \"$app_path\""
        done <<< "$flagged_apps"
        remediation="$block_cmds"
    else
        res_status="PASS"
        details="No dangerous scripting interpreters or raw networking tools allowed incoming connections."
        remediation=""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# NET-04: BPF Device Sniffing Permissions
# Checks permissions of `/dev/bpf*` and whether current user is in `access_bpf` group.
# WARN if non-root user can capture raw packets without sudo.
audit_bpf_sniffing() {
    local check_id="${1:-NET-04}"
    local category="${2:-network}"
    local title="${3:-BPF Packet Capture Permissions}"
    local weight="${4:-7}"

    local res_status="PASS"
    local details=""
    local remediation=""

    local in_access_bpf=""
    if id -Gn 2>/dev/null | tr ' ' '\n' | grep -x 'access_bpf' >/dev/null 2>&1; then
        in_access_bpf="yes"
    fi

    local bpf_perms=""
    local bpf_group=""
    if [[ -e /dev/bpf0 ]]; then
        bpf_perms=$(ls -l /dev/bpf0 2>/dev/null | awk '{print $1}')
        bpf_group=$(ls -l /dev/bpf0 2>/dev/null | awk '{print $4}')
    fi

    local has_chmod_bpf=""
    if [[ -f /Library/LaunchDaemons/org.wireshark.ChmodBPF.plist ]]; then
        has_chmod_bpf="yes"
    fi

    # Check if permissions or group allow non-root packet sniffing
    local is_vulnerable=0
    local reasons=""

    if [[ -n "$in_access_bpf" ]]; then
        is_vulnerable=1
        reasons="${reasons:+$reasons; }Current user is a member of 'access_bpf' group"
    fi

    if [[ -n "$has_chmod_bpf" ]]; then
        is_vulnerable=1
        reasons="${reasons:+$reasons; }Wireshark ChmodBPF launch daemon installed (/Library/LaunchDaemons/org.wireshark.ChmodBPF.plist)"
    fi

    if [[ "$bpf_perms" =~ ^c..r || "$bpf_perms" =~ ^c.....r || "$bpf_perms" =~ ^c........r ]]; then
        # If group or other has read permissions
        if [[ "$bpf_perms" =~ ^c.....r ]] && [[ "$bpf_group" == "access_bpf" || "$bpf_group" == "staff" ]]; then
            is_vulnerable=1
            reasons="${reasons:+$reasons; }/dev/bpf* has group-accessible permissions ($bpf_perms, group: $bpf_group)"
        elif [[ "$bpf_perms" =~ ^c........r ]]; then
            is_vulnerable=1
            reasons="${reasons:+$reasons; }/dev/bpf* is world-readable ($bpf_perms)"
        fi
    fi

    if (( is_vulnerable == 1 )); then
        res_status="WARN"
        details="Non-root packet sniffing permitted: ${reasons}. Unprivileged users or compromised processes can capture network traffic."
        remediation="sudo dseditgroup -o edit -d $(whoami) -t user access_bpf 2>/dev/null; sudo chmod 600 /dev/bpf*"
    else
        res_status="PASS"
        details="Berkeley Packet Filter (/dev/bpf*) devices are strictly restricted to root."
        remediation=""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# NET-05: /etc/hosts Integrity
# Checks `/etc/hosts`. Ensures `127.0.0.1 localhost` and `::1 localhost` are NOT commented out or missing.
# FAIL/WARN if localhost loopback is disabled.
audit_hosts_integrity() {
    local check_id="${1:-NET-05}"
    local category="${2:-network}"
    local title="${3:-/etc/hosts Loopback Integrity}"
    local weight="${4:-8}"

    local res_status="PASS"
    local details=""
    local remediation=""

    local hosts_file="/etc/hosts"

    if [[ ! -f "$hosts_file" ]]; then
        res_status="FAIL"
        details="/etc/hosts file is completely missing! System hostname and loopback resolution is broken."
        remediation="sudo sh -c 'printf \"127.0.0.1\tlocalhost\n::1\tlocalhost\n255.255.255.255\tbroadcasthost\n\" > /etc/hosts'"
        record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
        return 0
    fi

    # Check IPv4 loopback: 127.0.0.1 localhost
    local ipv4_match
    ipv4_match=$(grep -E '^[[:space:]]*127\.0\.0\.1[[:space:]]+.*localhost' "$hosts_file" 2>/dev/null | grep -v '^[[:space:]]*#' || true)

    # Check IPv6 loopback: ::1 localhost
    local ipv6_match
    ipv6_match=$(grep -E '^[[:space:]]*::1[[:space:]]+.*localhost' "$hosts_file" 2>/dev/null | grep -v '^[[:space:]]*#' || true)

    # Check if loopback lines are commented out
    local commented_loopback
    commented_loopback=$(grep -E '^[[:space:]]*#[[:space:]]*(127\.0\.0\.1|::1)[[:space:]]+.*localhost' "$hosts_file" 2>/dev/null || true)

    if [[ -z "$ipv4_match" || -z "$ipv6_match" ]]; then
        res_status="FAIL"
        local missing=""
        [[ -z "$ipv4_match" ]] && missing="IPv4 127.0.0.1"
        [[ -z "$ipv6_match" ]] && missing="${missing:+$missing, }IPv6 ::1"
        details="Localhost loopback resolution missing or commented out in /etc/hosts (${missing})."
        remediation="sudo sh -c 'printf \"127.0.0.1\tlocalhost\n::1\tlocalhost\n\" >> /etc/hosts'"
    elif [[ -n "$commented_loopback" ]]; then
        res_status="WARN"
        details="Commented loopback entries detected in /etc/hosts alongside active mappings."
        remediation="sudo sed -i '' '/^#[[:space:]]*127\.0\.0\.1[[:space:]].*localhost/d' /etc/hosts"
    else
        res_status="PASS"
        details="IPv4 and IPv6 localhost loopback mappings in /etc/hosts are valid and active."
        remediation=""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# NET-06: Wildcard Exposed Network Listeners
# Runs `lsof -nP -iTCP -sTCP:LISTEN` or `netstat`.
# Checks for non-Apple services listening on `0.0.0.0` or `*` rather than `127.0.0.1`.
# WARN if external ports are exposed.
audit_listening_wildcards() {
    local check_id="${1:-NET-06}"
    local category="${2:-network}"
    local title="${3:-Wildcard Exposed TCP Listeners}"
    local weight="${4:-6}"

    local res_status="PASS"
    local details=""
    local remediation=""

    local listeners_raw=""
    if command -v lsof >/dev/null 2>&1; then
        listeners_raw=$(lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null || true)
    fi

    if [[ -z "$listeners_raw" ]]; then
        res_status="PASS"
        details="No active TCP listening sockets detected or lsof unavailable."
        record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
        return 0
    fi

    # Known Apple system processes listening on wildcard ports for AirPlay/Continuity
    local apple_system_regex="^(rapportd|ControlCenter|AirPlayXPCHelper|sharingd|launchd|cupsd|remoted|sshd-keygen-wrapper)$"

    local exposed_services=""
    local count_exposed=0
    local cmd=""
    local pid=""
    local node_addr=""

    # Parse listeners bound to *:port, 0.0.0.0:port, [::]:port
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        cmd=$(echo "$line" | awk '{print $1}')
        pid=$(echo "$line" | awk '{print $2}')
        node_addr=$(echo "$line" | awk '{print $3}')

        case "$node_addr" in
            \*:*|0.0.0.0:*|\[::\]:*)
                # Check if this is a known Apple system service
                if echo "$cmd" | grep -qE "$apple_system_regex"; then
                    continue
                fi

                # Check binary path if available
                local bin_path=""
                if [[ -n "$pid" ]]; then
                    bin_path=$(ps -p "$pid" -o comm= 2>/dev/null || echo "")
                fi

                # If binary is under /System/Library or /usr/libexec, treat as Apple system daemon
                if echo "$bin_path" | grep -qE "^/System/Library|^/usr/libexec"; then
                    continue
                fi

                local entry="${cmd} (PID ${pid}, ${node_addr})"
                exposed_services="${exposed_services:+$exposed_services; }${entry}"
                (( count_exposed++ ))
                ;;
        esac
    done <<< "$(echo "$listeners_raw" | awk 'NR>1 {print $1, $2, $(NF-1)}')"

    if (( count_exposed > 0 )); then
        res_status="WARN"
        details="Non-system services listening on external/wildcard interface (${count_exposed}): ${exposed_services}"
        remediation="Reconfigure exposed services to bind specifically to 127.0.0.1 (localhost) instead of 0.0.0.0 or *"
    else
        res_status="PASS"
        details="No unauthorized third-party services listening on wildcard (0.0.0.0 / *) interfaces."
        remediation=""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# Aliases for ID-based execution
audit_net_01() { audit_firewall "$@"; }
audit_net_02() { audit_firewall_stealth "$@"; }
audit_net_03() { audit_firewall_exceptions "$@"; }
audit_net_04() { audit_bpf_sniffing "$@"; }
audit_net_05() { audit_hosts_integrity "$@"; }
audit_net_06() { audit_listening_wildcards "$@"; }

# Category Runner
run_audit_network() {
    audit_firewall
    audit_firewall_stealth
    audit_firewall_exceptions
    audit_bpf_sniffing
    audit_hosts_integrity
    audit_listening_wildcards
}

# Auto-registration with engine.sh
register_network_checks() {
    if command -v register_check >/dev/null 2>&1 || typeset -f register_check >/dev/null 2>&1; then
        register_check "NET-01" "network" "Application Firewall Status" 9 audit_firewall
        register_check "NET-02" "network" "Firewall Stealth Mode" 5 audit_firewall_stealth
        register_check "NET-03" "network" "Firewall Permissive Exceptions" 8 audit_firewall_exceptions
        register_check "NET-04" "network" "BPF Packet Capture Permissions" 7 audit_bpf_sniffing
        register_check "NET-05" "network" "/etc/hosts Loopback Integrity" 8 audit_hosts_integrity
        register_check "NET-06" "network" "Wildcard Exposed TCP Listeners" 6 audit_listening_wildcards
    fi
}

register_network_checks
