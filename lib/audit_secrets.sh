#!/bin/zsh
# ==============================================================================
# macharden - lib/audit_secrets.sh
# Secrets & Credentials Audit Module: Shell Startup Files, Exposed .env Files,
# Keychain Timeout, Kernel Core Dumps, and SSH File Permissions
# ==============================================================================

# Ensure record_result fallback exists if sourced standalone
if ! command -v record_result >/dev/null 2>&1 && ! typeset -f record_result >/dev/null 2>&1; then
    record_result() {
        printf "[%s] %s (%s): %s - %s\n" "$4" "$1" "$2" "$3" "$6"
    }
fi

# Helper to get file octal permissions portably (macOS and Linux)
_get_octal_perms() {
    stat -f "%OLp" "$1" 2>/dev/null || stat -c "%a" "$1" 2>/dev/null || echo ""
}

# SEC-01: Plaintext Shell Secrets & Profile Permissions
# Inspects `~/.zshrc`, `~/.bashrc`, `~/.bash_profile`, `~/.zprofile` for plaintext API keys/tokens.
# FAIL if plaintext secrets found. Also checks file permissions (WARN if world-readable 644, suggest 600).
audit_shell_secrets() {
    local check_id="${1:-SEC-01}"
    local category="${2:-secrets}"
    local title="${3:-Plaintext API Keys in Shell Profiles}"
    local weight="${4:-9}"

    local res_status="PASS"
    local details=""
    local remediation=""

    local target_files=(
        "$HOME/.zshrc"
        "$HOME/.bashrc"
        "$HOME/.bash_profile"
        "$HOME/.zprofile"
        "$HOME/.zshenv"
        "$HOME/.profile"
    )

    local found_secrets=""
    local secret_count=0
    local world_readable_files=""
    local readable_count=0
    local perms=""
    local var_name=""
    local line_num=""
    local line_content=""
    local sq="'"

    # Pattern targeting popular API tokens and export patterns
    local pattern='(H1_API_TOKEN|OPENAI_API_KEY|DEEPSEEK_API_KEY|ANTHROPIC_API_KEY|ANTHROPIC_AUTH_TOKEN|AWS_SECRET_ACCESS_KEY|AWS_ACCESS_KEY_ID|SLACK_TOKEN|GITHUB_TOKEN|GH_TOKEN|export[[:space:]]+[A-Za-z0-9_]*(KEY|TOKEN|SECRET|PASSWORD|PASSWD)[[:space:]]*=)'

    for file in "${target_files[@]}"; do
        [[ ! -f "$file" ]] && continue

        # Check permissions using octal (e.g. 644 is group/world readable)
        perms=$(_get_octal_perms "$file")
        if [[ "$perms" =~ [4567]$ ]]; then
            world_readable_files="${world_readable_files:+$world_readable_files, }${file##*/} (${perms})"
            (( readable_count++ ))
        fi

        # Scan for plaintext secret assignments
        while IFS=: read -r line_num line_content; do
            [[ -z "$line_content" ]] && continue
            # Ignore commented lines
            if echo "$line_content" | grep -qE '^[[:space:]]*#'; then
                continue
            fi
            # Ignore command substitutions $(cat ...) or `cat ...`
            if echo "$line_content" | grep -qE '(\$\(|`)'; then
                continue
            fi
            # Ignore empty strings or dummy placeholder templates
            if echo "$line_content" | grep -qiE "=[[:space:]]*[\"$sq ]*(your_|xxx|<|placeholder|\\$|\"\"|${sq}${sq})"; then
                continue
            fi

            # Extract variable name and partially masked snippet
            var_name=$(echo "$line_content" | sed -n 's/.*export[[:space:]]*\([A-Za-z0-9_]*\)=.*/\1/p')
            [[ -z "$var_name" ]] && var_name=$(echo "$line_content" | sed -n 's/.*\([A-Za-z0-9_]*\)=.*/\1/p')

            local entry="${file##*/}:${line_num} (${var_name:-secret}=***)"
            found_secrets="${found_secrets:+$found_secrets; }${entry}"
            (( secret_count++ ))
        done <<< "$(grep -nE "$pattern" "$file" 2>/dev/null || true)"
    done

    if (( secret_count > 0 )); then
        res_status="FAIL"
        details="Plaintext secrets found in shell profiles (${secret_count}): ${found_secrets}"
        remediation="Remove hardcoded API keys and store them in macOS Keychain or environment vault. Set file permissions: chmod 600 ~/.zshrc ~/.bashrc ~/.bash_profile ~/.zprofile ~/.zshenv 2>/dev/null"
    elif (( readable_count > 0 )); then
        res_status="WARN"
        details="Shell startup files are world-readable (${world_readable_files}), exposing environment paths and configurations."
        remediation="chmod 600 ~/.zshrc ~/.bashrc ~/.bash_profile ~/.zprofile ~/.zshenv 2>/dev/null"
    else
        res_status="PASS"
        details="No plaintext API keys or secrets detected in shell profiles; permissions are protected."
        remediation=""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# SEC-02: Unprotected .env Configuration Files
# Scans common user project dirs (`~/Downloads`, `~/Documents`, `~/Projects`, `~/Desktop`)
# for world-readable `.env` files containing secrets. WARN if found.
audit_env_files() {
    local check_id="${1:-SEC-02}"
    local category="${2:-secrets}"
    local title="${3:-Exposed .env Configuration Files}"
    local weight="${4:-6}"

    local res_status="PASS"
    local details=""
    local remediation=""

    local scan_dirs=()
    for d in "$HOME/Downloads" "$HOME/Documents" "$HOME/Projects" "$HOME/Desktop" "$HOME/Developer" "$HOME/code"; do
        [[ -d "$d" ]] && scan_dirs+=("$d")
    done

    if (( ${#scan_dirs[@]} == 0 )); then
        res_status="PASS"
        details="No standard development directories found to scan for .env files."
        record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
        return 0
    fi

    local exposed_files=""
    local count_exposed=0
    local fix_cmds=""
    local env_path=""
    local perms=""
    local is_world_readable=0
    local has_secrets=0

    # Search up to depth 3 to avoid infinite loops or heavy disk scanning
    while IFS= read -r env_path; do
        [[ -z "$env_path" ]] && continue
        # Ignore example/sample/template files
        case "${env_path##*/}" in
            *.example|*.sample|*.template|*.dist|*.bak*)
                continue
                ;;
        esac

        perms=$(_get_octal_perms "$env_path")

        # Check if file is readable by group or other (world-readable: e.g. 644, 664, 755)
        is_world_readable=0
        if [[ "$perms" =~ [4567]$ || "$perms" =~ ^[0-9][4567][0-9]$ ]]; then
            is_world_readable=1
        fi

        # Check if it contains sensitive keyword variables
        has_secrets=0
        if grep -qE '(KEY|SECRET|TOKEN|PASSWORD|PASSWD)=' "$env_path" 2>/dev/null; then
            has_secrets=1
        fi

        if (( is_world_readable == 1 && has_secrets == 1 )); then
            # Display path relative to HOME for readability
            local rel_path="${env_path/#$HOME/~}"
            exposed_files="${exposed_files:+$exposed_files; }${rel_path} (${perms})"
            fix_cmds="${fix_cmds:+$fix_cmds; }chmod 600 \"$env_path\""
            (( count_exposed++ ))
        fi
    done <<< "$(find "${scan_dirs[@]}" -maxdepth 3 -type f -name ".env*" 2>/dev/null || true)"

    if (( count_exposed > 0 )); then
        res_status="WARN"
        details="World-readable .env secret files found (${count_exposed}): ${exposed_files}"
        remediation="${fix_cmds:+$fix_cmds && }echo 'Ensure .env files are included in .gitignore'"
    else
        res_status="PASS"
        details="No world-readable .env configuration files detected in common project directories."
        remediation=""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# SEC-03: Login Keychain Auto-Lock Timeout
# Checks `security show-keychain-info ~/Library/Keychains/login.keychain-db`.
# WARN/SUGG if `no-timeout` (suggest `security set-keychain-settings -t 900 -l`).
audit_keychain_timeout() {
    local check_id="${1:-SEC-03}"
    local category="${2:-secrets}"
    local title="${3:-Keychain Auto-Lock Timeout}"
    local weight="${4:-5}"

    local res_status="PASS"
    local details=""
    local remediation=""

    local kc_file="$HOME/Library/Keychains/login.keychain-db"
    [[ ! -f "$kc_file" ]] && kc_file="$HOME/Library/Keychains/login.keychain"

    local kc_out=""
    if [[ -f "$kc_file" ]]; then
        kc_out=$(security show-keychain-info "$kc_file" 2>&1 || true)
    else
        kc_out=$(security show-keychain-info 2>&1 || true)
    fi

    if echo "$kc_out" | grep -qi "no-timeout"; then
        res_status="SUGG"
        details="Login keychain is configured with 'no-timeout'. Credentials remain permanently unlocked during idle sessions."
        remediation="security set-keychain-settings -t 900 -l \"$HOME/Library/Keychains/login.keychain-db\""
    elif echo "$kc_out" | grep -qiE "timeout=[0-9]+s|lock-on-sleep"; then
        res_status="PASS"
        local setting_info
        setting_info=$(echo "$kc_out" | grep -oE '(lock-on-sleep|timeout=[0-9]+s)' | tr '\n' ' ' | sed 's/ $//')
        details="Login keychain auto-lock is configured: ${setting_info:-lock active}."
        remediation=""
    else
        res_status="WARN"
        details="Keychain status check returned: $(echo "$kc_out" | head -n 1)"
        remediation="security set-keychain-settings -t 900 -l \"$HOME/Library/Keychains/login.keychain-db\""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# SEC-04: Kernel Core Dumps
# Checks `sysctl -n kern.coredump`.
# WARN/SUGG if `1` (suggest `sysctl -w kern.coredump=0`).
audit_core_dumps() {
    local check_id="${1:-SEC-04}"
    local category="${2:-secrets}"
    local title="${3:-Kernel Core Dumps}"
    local weight="${4:-4}"

    local res_status="PASS"
    local details=""
    local remediation=""

    local coredump
    coredump=$(sysctl -n kern.coredump 2>/dev/null || echo "0")

    if [[ "$coredump" == "1" ]]; then
        res_status="SUGG"
        details="Kernel core dumps are enabled (kern.coredump=1). Crashed processes can write sensitive memory contents to disk."
        remediation="sudo sysctl -w kern.coredump=0"
    else
        res_status="PASS"
        details="Kernel core dumps are disabled (kern.coredump=0)."
        remediation=""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# SEC-05: SSH Permissions
# Checks `~/.ssh/` directory (`700`), private keys (`600`), and `config` permissions.
audit_ssh_permissions() {
    local check_id="${1:-SEC-05}"
    local category="${2:-secrets}"
    local title="${3:-SSH Keys and Config Permissions}"
    local weight="${4:-7}"

    local res_status="PASS"
    local details=""
    local remediation=""

    local ssh_dir="$HOME/.ssh"
    if [[ ! -d "$ssh_dir" ]]; then
        res_status="PASS"
        details="No ~/.ssh directory exists."
        record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
        return 0
    fi

    local issues=""
    local fix_cmds=""
    local key_file=""
    local priv_file=""
    local kperms=""
    local pperms=""
    local cperms=""

    # 1. Check ~/.ssh directory permissions (must be 700)
    local dir_perms
    dir_perms=$(_get_octal_perms "$ssh_dir")
    if [[ "$dir_perms" != "700" ]]; then
        issues="${issues:+$issues; }~/.ssh directory is group/world accessible (${dir_perms}, expected 700)"
        fix_cmds="${fix_cmds:+$fix_cmds; }chmod 700 ~/.ssh"
    fi

    # 2. Check private keys (must be 600 or 400)
    while IFS= read -r key_file; do
        [[ -z "$key_file" ]] && continue
        kperms=$(_get_octal_perms "$key_file")
        if [[ "$kperms" != "600" && "$kperms" != "400" ]]; then
            issues="${issues:+$issues; }Private key ${key_file##*/} has insecure permissions (${kperms}, expected 600)"
            fix_cmds="${fix_cmds:+$fix_cmds; }chmod 600 \"$key_file\""
        fi
    done <<< "$(find "$ssh_dir" -maxdepth 1 -type f \( -name "id_*" -o -name "*_id_*" -o -name "*.pem" -o -name "*.key" \) ! -name "*.pub" 2>/dev/null || true)"

    # Also check files containing PRIVATE KEY header
    while IFS= read -r priv_file; do
        [[ -z "$priv_file" ]] && continue
        pperms=$(_get_octal_perms "$priv_file")
        if [[ "$pperms" != "600" && "$pperms" != "400" ]]; then
            if ! echo "$issues" | grep -q "${priv_file##*/}"; then
                issues="${issues:+$issues; }Private key ${priv_file##*/} has insecure permissions (${pperms}, expected 600)"
                fix_cmds="${fix_cmds:+$fix_cmds; }chmod 600 \"$priv_file\""
            fi
        fi
    done <<< "$(grep -l "PRIVATE KEY" "$ssh_dir"/* 2>/dev/null || true)"

    # 3. Check ~/.ssh/config permissions (should be 600)
    local config_file="$ssh_dir/config"
    if [[ -f "$config_file" ]]; then
        cperms=$(_get_octal_perms "$config_file")
        if [[ "$cperms" != "600" ]]; then
            issues="${issues:+$issues; }SSH config file has insecure permissions (${cperms}, expected 600)"
            fix_cmds="${fix_cmds:+$fix_cmds; }chmod 600 \"$config_file\""
        fi
    fi

    if [[ -n "$issues" ]]; then
        res_status="WARN"
        details="Insecure SSH permissions detected: ${issues}"
        remediation="${fix_cmds:-chmod 700 ~/.ssh && chmod 600 ~/.ssh/id_* ~/.ssh/config 2>/dev/null}"
    else
        res_status="PASS"
        details="~/.ssh directory (700), private keys (600), and config file have secure permissions."
        remediation=""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# Aliases for ID-based execution
audit_sec_01() { audit_shell_secrets "$@"; }
audit_sec_02() { audit_env_files "$@"; }
audit_sec_03() { audit_keychain_timeout "$@"; }
audit_sec_04() { audit_core_dumps "$@"; }
audit_sec_05() { audit_ssh_permissions "$@"; }

# Category Runner
run_audit_secrets() {
    audit_shell_secrets
    audit_env_files
    audit_keychain_timeout
    audit_core_dumps
    audit_ssh_permissions
}

# Auto-registration with engine.sh
register_secrets_checks() {
    if command -v register_check >/dev/null 2>&1 || typeset -f register_check >/dev/null 2>&1; then
        register_check "SEC-01" "secrets" "Plaintext API Keys in Shell Profiles" 9 audit_shell_secrets
        register_check "SEC-02" "secrets" "Exposed .env Configuration Files" 6 audit_env_files
        register_check "SEC-03" "secrets" "Keychain Auto-Lock Timeout" 5 audit_keychain_timeout
        register_check "SEC-04" "secrets" "Kernel Core Dumps" 4 audit_core_dumps
        register_check "SEC-05" "secrets" "SSH Keys and Config Permissions" 7 audit_ssh_permissions
    fi
}

register_secrets_checks
