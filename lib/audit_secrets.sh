#!/bin/zsh
# ==============================================================================
# macharden - lib/audit_secrets.sh
# Secrets & Credentials Audit Module: Shell Startup Files, Exposed .env Files,
# Keychain Timeout, Kernel Core Dumps, SSH File Permissions,
# Unencrypted SSH Private Keys, Secrets in Shell History,
# SSH Daemon Hardening, and Suspicious History File Types
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

# Secret assignment regex used by SEC-01 and SEC-07.
# Matches known token names and `export NAME=value` without requiring whitespace around `=`.
_SEC_SECRET_PATTERN='(H1_API_TOKEN|OPENAI_API_KEY|DEEPSEEK_API_KEY|ANTHROPIC_API_KEY|ANTHROPIC_AUTH_TOKEN|AWS_SECRET_ACCESS_KEY|AWS_ACCESS_KEY_ID|SLACK_TOKEN|GITHUB_TOKEN|GH_TOKEN|[A-Za-z0-9_]*(KEY|TOKEN|SECRET|PASSWORD|PASSWD))[[:space:]]*='

# Extract the assignment name for masked reporting. Never return the secret value.
_sec_secret_var_name() {
    local line="$1"
    local var_name=""
    var_name=$(printf '%s\n' "$line" | grep -oE '[A-Za-z0-9_]*(KEY|TOKEN|SECRET|PASSWORD|PASSWD)[[:space:]]*=' | head -n 1 | sed -E 's/[[:space:]]*=$//')
    printf '%s\n' "${var_name:-secret}"
}

# Run a command with a hard deadline (seconds). stdin is /dev/null so prompts cannot block.
# stdout is returned; stderr is discarded. Timed-out processes are SIGTERM then SIGKILL.
_sec_run_limited() {
    local secs="${1:-5}"
    shift
    [[ $# -gt 0 ]] || return 1

    if ! command -v perl >/dev/null 2>&1; then
        "$@" </dev/null 2>/dev/null
        return $?
    fi

    perl -e '
        use strict;
        my $timeout = shift @ARGV;
        my $pid = fork();
        if (!defined $pid) { exit 1 }
        if ($pid == 0) {
            open(STDIN, "<", "/dev/null") or exit 1;
            open(STDERR, ">", "/dev/null");
            exec { $ARGV[0] } @ARGV;
            exit 127;
        }
        $SIG{ALRM} = sub {
            kill "TERM", $pid;
            select(undef, undef, undef, 0.2);
            kill "KILL", $pid;
            waitpid($pid, 0);
            exit 124;
        };
        alarm $timeout;
        waitpid($pid, 0);
        alarm 0;
        my $st = $?;
        if ($st == -1) { exit 1 }
        if ($st & 127) { exit 1 }
        exit($st >> 8);
    ' "$secs" "$@"
}

# True if anything is in TCP LISTEN on port 22 (IPv4 or IPv6).
_sec_has_tcp22_listener() {
    local out=""
    local bin=""

    if command -v lsof >/dev/null 2>&1; then
        bin=$(command -v lsof)
        out=$(_sec_run_limited 5 "$bin" -nP -iTCP:22 -sTCP:LISTEN)
        if printf '%s\n' "$out" | grep -q LISTEN; then
            return 0
        fi
    fi

    if command -v netstat >/dev/null 2>&1; then
        bin=$(command -v netstat)
        out=$(_sec_run_limited 5 "$bin" -an -p tcp)
        if printf '%s\n' "$out" | grep -qE '[.:]22[[:space:]].*LISTEN'; then
            return 0
        fi
    fi

    return 1
}

# Last value for an sshd keyword in config text. Prints a lowercase token; empty if unset.
_sec_ssh_option() {
    local key="$1"
    local text="$2"
    printf '%s\n' "$text" | awk -v k="$key" '
        BEGIN { key = tolower(k) }
        $1 ~ /^#/ { next }
        tolower($1) == key { val = tolower($2) }
        END { if (val != "") print val }
    '
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

    # Pattern targeting popular API tokens and export assignments (no required whitespace around =)
    local pattern="$_SEC_SECRET_PATTERN"

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

            # Extract variable name only; never include the secret value
            var_name=$(_sec_secret_var_name "$line_content")

            local entry="${file##*/}:${line_num} (${var_name}=***)"
            found_secrets="${found_secrets:+$found_secrets; }${entry}"
            (( secret_count++ ))
        done <<< "$(grep -nE "$pattern" "$file" 2>/dev/null || true)"
    done

    if (( secret_count > 0 )); then
        res_status="FAIL"
        details="Plaintext secrets found in shell profiles (${secret_count}): ${found_secrets}"
        remediation="[EXEC] chmod 600 ~/.zshrc ~/.bashrc ~/.bash_profile ~/.zprofile ~/.zshenv 2>/dev/null"
    elif (( readable_count > 0 )); then
        res_status="WARN"
        details="Shell startup files are world-readable (${world_readable_files}), exposing environment paths and configurations."
        remediation="[EXEC] chmod 600 ~/.zshrc ~/.bashrc ~/.bash_profile ~/.zprofile ~/.zshenv 2>/dev/null"
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
    done <<< "$(find "${scan_dirs[@]}" -maxdepth 3 -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/vendor/*' -not -path '*/.venv/*' -not -path '*/__pycache__/*' -type f -name ".env*" 2>/dev/null || true)"

    if (( count_exposed > 0 )); then
        res_status="WARN"
        details="World-readable .env secret files found (${count_exposed}): ${exposed_files}"
        remediation="[EXEC] ${fix_cmds:+$fix_cmds && }echo 'Ensure .env files are included in .gitignore'"
    else
        res_status="PASS"
        details="No world-readable .env configuration files detected in common project directories."
        remediation=""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# SEC-03: Login Keychain Lock Policy (organization-defined value)
# Checks `security show-keychain-info ~/Library/Keychains/login.keychain-db`.
# The login-keychain timeout is deliberately not auto-remediated: changing it
# can cause repeated password prompts and is a threat-model/user-experience
# choice. Profiles may define keychain-timeout and keychain-lock-on-sleep.
audit_keychain_timeout() {
    local check_id="${1:-SEC-03}"
    local category="${2:-secrets}"
    local title="${3:-Keychain Lock Policy}"
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

    local expected_timeout="${MACHAR_KEYCHAIN_TIMEOUT_SECONDS:-}"
    local expected_sleep="${MACHAR_KEYCHAIN_LOCK_ON_SLEEP:-}"
    local actual_timeout=""
    local has_sleep_lock=0
    local setting_info=""

    actual_timeout=$(echo "$kc_out" | sed -nE 's/.*timeout=([0-9]+)s.*/\1/p' | head -n 1)
    echo "$kc_out" | grep -qi "lock-on-sleep" && has_sleep_lock=1
    setting_info=$(echo "$kc_out" | grep -oE '(no-timeout|lock-on-sleep|timeout=[0-9]+s)' | tr '\n' ' ' | sed 's/ $//')

    if ! echo "$kc_out" | grep -qiE "no-timeout|timeout=[0-9]+s|lock-on-sleep"; then
        res_status="INFO"
        details="Login keychain policy could not be read safely; no change will be proposed from an ambiguous result."
        remediation="[GUIDE] Inspect in Keychain Access > Settings for the login keychain. Do not change the timeout based on this inconclusive check."
    elif [[ "$expected_timeout" == "none" ]]; then
        if echo "$kc_out" | grep -qi "no-timeout"; then
            res_status="INFO"
            details="Login keychain matches the profile's explicit no-timeout exception. The control is neutral rather than counted as framework-compliant."
        else
            res_status="INFO"
            details="Login keychain is stricter than the profile's explicit no-timeout exception (${setting_info}); the exception remains neutral."
        fi
        remediation=""
    elif [[ "$expected_timeout" =~ ^[0-9]+$ ]]; then
        local timeout_ok=0 sleep_ok=1
        [[ "$actual_timeout" =~ ^[0-9]+$ ]] && (( actual_timeout <= expected_timeout )) && timeout_ok=1
        [[ "$expected_sleep" == "yes" && $has_sleep_lock -ne 1 ]] && sleep_ok=0

        if (( timeout_ok && sleep_ok )); then
            res_status="PASS"
            details="Login keychain meets the profile policy (${setting_info}; maximum ${expected_timeout}s${expected_sleep:+, lock-on-sleep=${expected_sleep}})."
            remediation=""
        else
            res_status="WARN"
            details="Login keychain does not meet the profile policy (current: ${setting_info:-unknown}; maximum ${expected_timeout}s${expected_sleep:+, lock-on-sleep=${expected_sleep}})."
            local sleep_flag=""
            [[ "$expected_sleep" == "yes" ]] && sleep_flag=" -l"
            remediation="[GUIDE] This user-impacting policy requires explicit opt-in. Apply: security set-keychain-settings -t ${expected_timeout}${sleep_flag} \"${kc_file}\". Restore no-timeout/no-sleep-lock: security set-keychain-settings \"${kc_file}\"."
        fi
    elif echo "$kc_out" | grep -qi "no-timeout"; then
        res_status="SUGG"
        details="Login keychain uses no timeout and no organization-defined value is set. Choose a policy from the threat model before changing login behavior."
        remediation="[GUIDE] Optional: set keychain-timeout=900 and keychain-lock-on-sleep=yes in a macharden profile, review the impact, then apply manually. Restore with: security set-keychain-settings \"${kc_file}\"."
    else
        res_status="PASS"
        details="Login keychain auto-lock is configured (${setting_info}); no organization-defined maximum was selected."
        remediation=""
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
    local weight="${4:-5}"

    local res_status="PASS"
    local details=""
    local remediation=""

    local coredump
    coredump=$(sysctl -n kern.coredump 2>/dev/null || echo "0")

    if [[ "$coredump" == "1" ]]; then
        res_status="SUGG"
        details="Kernel core dumps are enabled (kern.coredump=1). Crashed processes can write sensitive memory contents to disk."
        remediation="[EXEC] sudo sysctl -w kern.coredump=0"
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
        remediation="[EXEC] ${fix_cmds:-chmod 700 ~/.ssh && chmod 600 ~/.ssh/id_* ~/.ssh/config 2>/dev/null}"
    else
        res_status="PASS"
        details="~/.ssh directory (700), private keys (600), and config file have secure permissions."
        remediation=""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# SEC-06: Unencrypted SSH Private Keys
# Scans `~/.ssh` for private keys (same discovery as SEC-05). WARN if any key
# is stored without a passphrase. Remediation is a reviewable `ssh-keygen -p`
# command; do not auto-change passphrases.
audit_unencrypted_ssh_keys() {
    local check_id="${1:-SEC-06}"
    local category="${2:-secrets}"
    local title="${3:-Unencrypted SSH Private Keys}"
    local weight="${4:-8}"

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

    local unencrypted_names=""
    local fix_cmds=""
    local unencrypted_count=0
    local seen_keys="|"
    local key_file=""
    local key_base=""
    local display_path=""

    # Collect private keys: filename patterns (same as SEC-05) plus PRIVATE KEY headers
    while IFS= read -r key_file; do
        [[ -z "$key_file" ]] && continue
        [[ ! -f "$key_file" ]] && continue
        key_base="${key_file##*/}"
        [[ "$key_base" == *.pub ]] && continue
        if [[ "$seen_keys" == *"|$key_file|"* ]]; then
            continue
        fi
        seen_keys="${seen_keys}${key_file}|"

        # PEM/PKCS#8: encrypted if the file contains these markers
        if grep -qE 'ENCRYPTED|Proc-Type: 4,ENCRYPTED' "$key_file" 2>/dev/null; then
            continue
        fi

        # OpenSSH new-format keys omit those markers even when passphrase-protected.
        # Test empty passphrase without prompting; success means unencrypted.
        if grep -q "BEGIN OPENSSH PRIVATE KEY" "$key_file" 2>/dev/null; then
            if ssh-keygen -y -P "" -f "$key_file" </dev/null >/dev/null 2>&1; then
                unencrypted_names="${unencrypted_names:+$unencrypted_names, }${key_base}"
                display_path="${key_file/#$HOME/~}"
                fix_cmds="${fix_cmds:+$fix_cmds; }ssh-keygen -p -f ${display_path}"
                (( unencrypted_count++ ))
            fi
            continue
        fi

        # Other private keys without encryption markers are unencrypted
        unencrypted_names="${unencrypted_names:+$unencrypted_names, }${key_base}"
        display_path="${key_file/#$HOME/~}"
        fix_cmds="${fix_cmds:+$fix_cmds; }ssh-keygen -p -f ${display_path}"
        (( unencrypted_count++ ))
    done <<< "$(
        {
            find "$ssh_dir" -maxdepth 1 -type f \( -name "id_*" -o -name "*_id_*" -o -name "*.pem" -o -name "*.key" \) ! -name "*.pub" 2>/dev/null
            grep -l "PRIVATE KEY" "$ssh_dir"/* 2>/dev/null
        } | sort -u
        true
    )"

    if (( unencrypted_count > 0 )); then
        res_status="WARN"
        details="Unencrypted SSH private key(s) found (${unencrypted_count}): ${unencrypted_names}"
        remediation="[EXEC] ${fix_cmds}"
    else
        res_status="PASS"
        details="No unencrypted SSH private keys found in ~/.ssh."
        remediation=""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# SEC-07: Secrets in Shell History
# Scans `~/.zsh_history`, `~/.zhistory`, and `~/.bash_history` with the SEC-01
# secret regex. Never prints live secret values.
audit_shell_history_secrets() {
    local check_id="${1:-SEC-07}"
    local category="${2:-secrets}"
    local title="${3:-Secrets in Shell History}"
    local weight="${4:-7}"

    local res_status="PASS"
    local details=""
    local remediation=""

    local history_files=(
        "$HOME/.zsh_history"
        "$HOME/.zhistory"
        "$HOME/.bash_history"
    )

    local found_secrets=""
    local secret_count=0
    local file=""
    local var_name=""
    local line_num=""
    local line_content=""
    local cmd_text=""
    local sq="'"
    local pattern="$_SEC_SECRET_PATTERN"

    for file in "${history_files[@]}"; do
        [[ ! -f "$file" ]] && continue

        while IFS=: read -r line_num line_content; do
            [[ -z "$line_content" ]] && continue

            # zsh EXTENDED_HISTORY: ": <timestamp>:<duration>;<command>"
            cmd_text="$line_content"
            if echo "$cmd_text" | grep -qE '^: [0-9]+:[0-9]+;'; then
                cmd_text="${cmd_text#*;}"
            fi

            # Ignore commented lines
            if echo "$cmd_text" | grep -qE '^[[:space:]]*#'; then
                continue
            fi
            # Ignore command substitutions $(cat ...) or `cat ...`
            if echo "$cmd_text" | grep -qE '(\$\(|`)'; then
                continue
            fi
            # Ignore empty strings or dummy placeholder templates
            if echo "$cmd_text" | grep -qiE "=[[:space:]]*[\"$sq ]*(your_|xxx|<|placeholder|\\$|\"\"|${sq}${sq})"; then
                continue
            fi

            # Extract variable name only; never include the secret value
            var_name=$(_sec_secret_var_name "$cmd_text")

            local entry="${file##*/}:${line_num} (${var_name}=***)"
            found_secrets="${found_secrets:+$found_secrets; }${entry}"
            (( secret_count++ ))
        done <<< "$(grep -nE "$pattern" "$file" 2>/dev/null || true)"
    done

    if (( secret_count > 0 )); then
        res_status="WARN"
        details="Secrets found in shell history (${secret_count}): ${found_secrets}"
        remediation="[GUIDE] Remove matching lines from shell history files (do not truncate the entire history). Example: sed -i '' '/TOKEN/d' ~/.zsh_history"
    else
        res_status="PASS"
        details="No secrets detected in shell history files."
        remediation=""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# SEC-08: SSH Daemon Hardening
# Skip with PASS when Remote Login is not On and nothing listens on TCP/22.
# Otherwise inspect `sshd -T` (preferred) or readable `/etc/ssh/sshd_config`.
# Never dumps config/secrets; never waits on admin prompts.
audit_sshd_hardening() {
    local check_id="${1:-SEC-08}"
    local category="${2:-secrets}"
    local title="${3:-SSH Daemon Hardening}"
    local weight="${4:-7}"

    local res_status="PASS"
    local details=""
    local remediation=""

    local rl_out=""
    local remote_on=0
    local listening=0
    local cfg=""
    local config_ok=0
    local sshd_bin=""
    local val=""
    local weak=""
    local f=""
    local -a cfg_files

    if [[ -x /usr/sbin/systemsetup ]]; then
        rl_out=$(_sec_run_limited 5 /usr/sbin/systemsetup -getremotelogin)
    elif command -v systemsetup >/dev/null 2>&1; then
        rl_out=$(_sec_run_limited 5 systemsetup -getremotelogin)
    fi
    if printf '%s\n' "$rl_out" | grep -qiE 'Remote Login:[[:space:]]*On'; then
        remote_on=1
    fi

    if _sec_has_tcp22_listener; then
        listening=1
    fi

    if (( remote_on == 0 && listening == 0 )); then
        res_status="PASS"
        details="sshd not exposed; daemon hardening skipped."
        record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
        return 0
    fi

    if [[ -x /usr/sbin/sshd ]]; then
        sshd_bin="/usr/sbin/sshd"
    elif command -v sshd >/dev/null 2>&1; then
        sshd_bin=$(command -v sshd)
    fi

    if [[ -n "$sshd_bin" ]]; then
        cfg=$(_sec_run_limited 5 "$sshd_bin" -T)
        if [[ -z "$cfg" ]] && command -v sudo >/dev/null 2>&1; then
            cfg=$(_sec_run_limited 5 sudo -n "$sshd_bin" -T)
        fi
        if [[ -n "$cfg" ]] && printf '%s\n' "$cfg" | grep -qiE '^permitrootlogin|^passwordauthentication|^x11forwarding|^maxauthtries|^permitemptypasswords'; then
            config_ok=1
        elif [[ -n "$cfg" ]] && printf '%s\n' "$cfg" | grep -qE '^[a-z][a-z0-9]+[[:space:]]'; then
            config_ok=1
        else
            cfg=""
        fi
    fi

    if (( config_ok == 0 )); then
        cfg_files=()
        [[ -r /etc/ssh/sshd_config ]] && cfg_files+=("/etc/ssh/sshd_config")
        for f in /etc/ssh/sshd_config.d/* /etc/ssh/crypto.conf; do
            [[ -r "$f" ]] && cfg_files+=("$f")
        done
        if (( ${#cfg_files[@]} > 0 )); then
            cfg=$(grep -hEi '^[[:space:]]*(PermitRootLogin|PasswordAuthentication|X11Forwarding|MaxAuthTries|PermitEmptyPasswords)[[:space:]]+' "${cfg_files[@]}" 2>/dev/null || true)
            config_ok=1
        fi
    fi

    if (( config_ok == 0 )); then
        res_status="INFO"
        details="SSH is exposed but configuration is unreadable (sshd -T failed and /etc/ssh/sshd_config is not readable)."
        remediation="[GUIDE] Inspect /etc/ssh/sshd_config (PermitRootLogin no, MaxAuthTries 4, X11Forwarding no). Do not rewrite sshd_config automatically."
        record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
        return 0
    fi

    val=$(_sec_ssh_option "permitrootlogin" "$cfg")
    if [[ "$val" == "yes" ]]; then
        weak="${weak:+$weak, }PermitRootLogin yes"
    fi
    val=$(_sec_ssh_option "passwordauthentication" "$cfg")
    if [[ "$val" == "yes" ]]; then
        weak="${weak:+$weak, }PasswordAuthentication yes"
    fi
    val=$(_sec_ssh_option "x11forwarding" "$cfg")
    if [[ "$val" == "yes" ]]; then
        weak="${weak:+$weak, }X11Forwarding yes"
    fi
    val=$(_sec_ssh_option "maxauthtries" "$cfg")
    if [[ "$val" =~ ^[0-9]+$ ]] && (( val > 6 )); then
        weak="${weak:+$weak, }MaxAuthTries ${val}"
    fi
    val=$(_sec_ssh_option "permitemptypasswords" "$cfg")
    if [[ "$val" == "yes" ]]; then
        weak="${weak:+$weak, }PermitEmptyPasswords yes"
    fi

    if [[ -n "$weak" ]]; then
        res_status="WARN"
        details="SSH daemon exposed with weak settings: ${weak}"
        remediation="[GUIDE] Review /etc/ssh/sshd_config: set PermitRootLogin no, MaxAuthTries 4, X11Forwarding no. Do not rewrite sshd_config automatically."
    else
        res_status="PASS"
        details="SSH daemon is exposed; no weak sshd options detected."
        remediation=""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# SEC-09: Suspicious Shell History Files
# WARN if ~/.zsh_history, ~/.zhistory, or ~/.bash_history exists and is not a
# regular file (symlink, directory, device). PASS if missing or regular files.
audit_suspicious_history_files() {
    local check_id="${1:-SEC-09}"
    local category="${2:-secrets}"
    local title="${3:-Suspicious Shell History Files}"
    local weight="${4:-5}"

    local res_status="PASS"
    local details=""
    local remediation=""

    local history_files=(
        "$HOME/.zsh_history"
        "$HOME/.zhistory"
        "$HOME/.bash_history"
    )

    local suspicious=""
    local count=0
    local file=""
    local kind=""
    local display=""

    for file in "${history_files[@]}"; do
        if [[ ! -e "$file" && ! -L "$file" ]]; then
            continue
        fi
        if [[ -f "$file" && ! -L "$file" ]]; then
            continue
        fi

        display="${file/#$HOME/~}"
        if [[ -L "$file" ]]; then
            kind="symlink"
        elif [[ -d "$file" ]]; then
            kind="directory"
        elif [[ -p "$file" ]]; then
            kind="fifo"
        elif [[ -S "$file" ]]; then
            kind="socket"
        elif [[ -b "$file" || -c "$file" ]]; then
            kind="device"
        else
            kind="non-regular"
        fi
        suspicious="${suspicious:+$suspicious, }${display} (${kind})"
        (( count++ ))
    done

    if (( count > 0 )); then
        res_status="WARN"
        details="Suspicious shell history file type(s) (${count}): ${suspicious}"
        remediation="[GUIDE] Investigate redirected history files (symlinks can hide attacker activity). Replace with a regular file."
    else
        res_status="PASS"
        details="Shell history files are missing or regular files (~/.zsh_history, ~/.zhistory, ~/.bash_history)."
        remediation=""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# SEC-10: Insecure PATH Directory Permissions & Hijacking Risk
# Checks directories in $PATH for world-writable permissions ('w' for others)
# and checks if '.' (current directory) or empty entry is in $PATH (MITRE T1574.007).
# FAIL/WARN if world-writable directory or '.' found; PASS if clean.
audit_insecure_path_dirs() {
    local check_id="${1:-SEC-10}"
    local category="${2:-secrets}"
    local title="${3:-Insecure PATH Directory Permissions}"
    local weight="${4:-7}"

    local res_status="PASS"
    local details=""
    local remediation=""

    local has_dot=0
    local ww_count=0
    local ww_dirs=""
    local fix_cmds=""
    local perms=""

    local -a raw_paths=()
    if [[ -n "$ZSH_VERSION" ]]; then
        raw_paths=("${(@s/:/)PATH}")
    else
        local saved_ifs="$IFS"
        IFS=':'
        raw_paths=($PATH)
        IFS="$saved_ifs"
    fi

    local p
    for p in "${raw_paths[@]}"; do
        if [[ "$p" == "." || -z "$p" ]]; then
            has_dot=1
            continue
        fi

        if [[ -d "$p" ]]; then
            perms=$(_get_octal_perms "$p")
            if [[ -n "$perms" ]]; then
                local last_digit="${perms: -1}"
                if [[ "$last_digit" =~ [2367] ]]; then
                    (( ww_count++ ))
                    ww_dirs="${ww_dirs:+$ww_dirs, }${p} (${perms})"
                    fix_cmds="${fix_cmds:+$fix_cmds; }chmod o-w \"$p\""
                fi
            fi
        fi
    done

    if (( has_dot )) && (( ww_count > 0 )); then
        res_status="FAIL"
        details="Current directory ('.') is in \$PATH and world-writable directories found (${ww_count}): ${ww_dirs} (MITRE T1574.007)."
        remediation="[EXEC] ${fix_cmds}"
    elif (( has_dot )); then
        res_status="FAIL"
        details="Current directory ('.') or empty entry detected in \$PATH (privilege escalation risk via PATH hijacking / MITRE T1574.007)."
        remediation="[GUIDE] Remove '.' and empty entries from PATH in shell profiles (~/.zshrc, ~/.bashrc) and /etc/paths."
    elif (( ww_count > 0 )); then
        res_status="WARN"
        details="World-writable directory found in \$PATH (${ww_count}): ${ww_dirs} (MITRE T1574.007)."
        remediation="[EXEC] ${fix_cmds}"
    else
        res_status="PASS"
        details="All directories in \$PATH have secure permissions and current directory ('.') is not in \$PATH."
        remediation=""
    fi

    record_result "$check_id" "$category" "$title" "$res_status" "$weight" "$details" "$remediation"
}

# SEC-11: Cloud & Sensitive API Credentials File Permissions
# Inspects permissions of sensitive files: ~/.aws/credentials, ~/.kube/config,
# ~/.netrc, ~/.docker/config.json. If they exist and permissions are not 600 or 400
# (world or group readable/writable), WARN/FAIL. PASS if clean or files do not exist.
audit_cloud_credentials() {
    local check_id="${1:-SEC-11}"
    local category="${2:-secrets}"
    local title="${3:-Cloud and API Credentials File Permissions}"
    local weight="${4:-8}"

    local res_status="PASS"
    local details=""
    local remediation=""

    local -a check_files=(
        "${HOME}/.aws/credentials"
        "${HOME}/.kube/config"
        "${HOME}/.netrc"
        "${HOME}/.docker/config.json"
    )

    local insecure_count=0
    local has_world_readable=0
    local insecure_details=""
    local fix_cmds=""
    local perms=""

    local f
    for f in "${check_files[@]}"; do
        if [[ -f "$f" ]]; then
            perms=$(_get_octal_perms "$f")
            if [[ ${#perms} -gt 3 ]]; then
                perms="${perms: -3}"
            fi

            # Clean permissions are 600 or 400
            if [[ "$perms" != "600" && "$perms" != "400" ]]; then
                (( insecure_count++ ))
                local display_path="~${f#$HOME}"
                insecure_details="${insecure_details:+$insecure_details; }${display_path} (${perms}, expected 600 or 400)"
                fix_cmds="${fix_cmds:+$fix_cmds; }chmod 600 \"$f\""

                local last_digit="${perms: -1}"
                if [[ "$last_digit" =~ [4567] ]]; then
                    has_world_readable=1
                fi
            fi
        fi
    done

    if (( insecure_count > 0 )); then
        if (( has_world_readable )); then
            res_status="FAIL"
        else
            res_status="WARN"
        fi
        details="Sensitive credential files have insecure permissions (${insecure_count}): ${insecure_details}."
        remediation="[EXEC] ${fix_cmds}"
    else
        res_status="PASS"
        details="Cloud and API credentials files (~/.aws/credentials, ~/.kube/config, ~/.netrc, ~/.docker/config.json) have secure permissions (600/400) or do not exist."
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
audit_sec_06() { audit_unencrypted_ssh_keys "$@"; }
audit_sec_07() { audit_shell_history_secrets "$@"; }
audit_sec_08() { audit_sshd_hardening "$@"; }
audit_sec_09() { audit_suspicious_history_files "$@"; }
audit_sec_10() { audit_insecure_path_dirs "$@"; }
audit_sec_11() { audit_cloud_credentials "$@"; }

# Category Runner
run_audit_secrets() {
    audit_shell_secrets
    audit_env_files
    audit_keychain_timeout
    audit_core_dumps
    audit_ssh_permissions
    audit_unencrypted_ssh_keys
    audit_shell_history_secrets
    audit_sshd_hardening
    audit_suspicious_history_files
    audit_insecure_path_dirs
    audit_cloud_credentials
}

# Auto-registration with engine.sh
register_secrets_checks() {
    if command -v register_check >/dev/null 2>&1 || typeset -f register_check >/dev/null 2>&1; then
        register_check "SEC-01" "secrets" "Plaintext API Keys in Shell Profiles" 9 audit_shell_secrets
        register_check "SEC-02" "secrets" "Exposed .env Configuration Files" 6 audit_env_files
        register_check "SEC-03" "secrets" "Keychain Lock Policy" 5 audit_keychain_timeout
        register_check "SEC-04" "secrets" "Kernel Core Dumps" 5 audit_core_dumps
        register_check "SEC-05" "secrets" "SSH Keys and Config Permissions" 7 audit_ssh_permissions
        register_check "SEC-06" "secrets" "Unencrypted SSH Private Keys" 8 audit_unencrypted_ssh_keys
        register_check "SEC-07" "secrets" "Secrets in Shell History" 7 audit_shell_history_secrets
        register_check "SEC-08" "secrets" "SSH Daemon Hardening" 7 audit_sshd_hardening
        register_check "SEC-09" "secrets" "Suspicious Shell History Files" 5 audit_suspicious_history_files
        register_check "SEC-10" "secrets" "Insecure PATH Directory Permissions" 7 audit_insecure_path_dirs
        register_check "SEC-11" "secrets" "Cloud and API Credentials File Permissions" 8 audit_cloud_credentials
    fi
}

register_secrets_checks
