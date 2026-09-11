#!/bin/zsh
# ==============================================================================
# macharden - lib/ui.sh
# Terminal UI, ANSI styling, ASCII banners, status indicators, and progress bars
# ==============================================================================

# Initialize or reset ANSI color codes
ui_init_colors() {
    if [[ "${MACHAR_NO_COLOR:-0}" -eq 1 ]] || [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 && -z "${MACHAR_FORCE_COLOR:-}" ]]; then
        COLOR_RESET=""
        COLOR_BOLD=""
        COLOR_DIM=""
        COLOR_UNDERLINE=""
        COLOR_RED=""
        COLOR_GREEN=""
        COLOR_YELLOW=""
        COLOR_BLUE=""
        COLOR_MAGENTA=""
        COLOR_CYAN=""
        COLOR_WHITE=""
        COLOR_BRED=""
        COLOR_BGREEN=""
        COLOR_BYELLOW=""
        COLOR_BBLUE=""
        COLOR_BMAGENTA=""
        COLOR_BCYAN=""
        COLOR_BWHITE=""
        BG_RED=""
        BG_GREEN=""
        BG_YELLOW=""
        BG_BLUE=""
    else
        COLOR_RESET="\033[0m"
        COLOR_BOLD="\033[1m"
        COLOR_DIM="\033[2m"
        COLOR_UNDERLINE="\033[4m"
        COLOR_RED="\033[31m"
        COLOR_GREEN="\033[32m"
        COLOR_YELLOW="\033[33m"
        COLOR_BLUE="\033[34m"
        COLOR_MAGENTA="\033[35m"
        COLOR_CYAN="\033[36m"
        COLOR_WHITE="\033[37m"
        COLOR_BRED="\033[91m"
        COLOR_BGREEN="\033[92m"
        COLOR_BYELLOW="\033[93m"
        COLOR_BBLUE="\033[94m"
        COLOR_BMAGENTA="\033[95m"
        COLOR_BCYAN="\033[96m"
        COLOR_BWHITE="\033[97m"
        BG_RED="\033[41m"
        BG_GREEN="\033[42m"
        BG_YELLOW="\033[43m"
        BG_BLUE="\033[44m"
    fi
}

# Explicitly disable colors
ui_disable_colors() {
    MACHAR_NO_COLOR=1
    ui_init_colors
}

# Display ASCII banner with system metadata
ui_banner() {
    local version="${MACHAR_VERSION:-1.1.0}"
    local os_product os_version os_build arch current_time current_user hostname

    os_product=$(sw_vers -productName 2>/dev/null || echo "macOS")
    os_version=$(sw_vers -productVersion 2>/dev/null || echo "Unknown")
    os_build=$(sw_vers -buildVersion 2>/dev/null || echo "Unknown")
    arch=$(uname -m 2>/dev/null || echo "arm64")
    current_time=$(date "+%Y-%m-%d %H:%M:%S %Z")
    current_user=$(id -un 2>/dev/null || whoami)
    hostname=$(hostname -s 2>/dev/null || hostname)

    cat <<EOF
${COLOR_BCYAN}                   _                     _            ${COLOR_RESET}
${COLOR_BCYAN}  _ __ ___   __ _  ___| |__   __ _ _ __   __| | ___ _ __  ${COLOR_RESET}
${COLOR_BCYAN} | '_ \` _ \ / _\` |/ __| '_ \ / _\` | '__| / _\` |/ _ \ '_ \ ${COLOR_RESET}
${COLOR_BCYAN} | | | | | | (_| | (__| | | | (_| | |   | (_| |  __/ | | |${COLOR_RESET}
${COLOR_BCYAN} |_| |_| |_|\__,_|\___|_| |_|\__,_|_|    \__,_|\___|_| |_|${COLOR_RESET}
${COLOR_DIM}  macOS Security Hardening & Audit Scanner  v${version}${COLOR_RESET}
${COLOR_DIM}──────────────────────────────────────────────────────────────────────${COLOR_RESET}
 ${COLOR_BOLD}Target Host:${COLOR_RESET}   ${COLOR_WHITE}${hostname}${COLOR_RESET} (${COLOR_DIM}${current_user}${COLOR_RESET})
 ${COLOR_BOLD}macOS Build:${COLOR_RESET}   ${COLOR_WHITE}${os_product} ${os_version} (Build ${os_build}) [${arch}]${COLOR_RESET}
 ${COLOR_BOLD}Audit Time:${COLOR_RESET}    ${COLOR_WHITE}${current_time}${COLOR_RESET}
${COLOR_DIM}──────────────────────────────────────────────────────────────────────${COLOR_RESET}
EOF
}

# Section header separator
ui_section() {
    local title="$1"
    echo ""
    echo "${COLOR_BOLD}${COLOR_BCYAN}▶ ${title}${COLOR_RESET}"
    echo "${COLOR_DIM}----------------------------------------------------------------------${COLOR_RESET}"
}

# Formatted check result row
ui_result() {
    local check_status="${1:u}"
    local id="$2"
    local title="$3"
    local details="${4:-}"

    local badge=""
    case "$check_status" in
        PASS)
            badge="${COLOR_BGREEN}${COLOR_BOLD}[PASS]${COLOR_RESET}"
            ;;
        WARN)
            badge="${COLOR_BYELLOW}${COLOR_BOLD}[WARN]${COLOR_RESET}"
            ;;
        FAIL)
            badge="${COLOR_BRED}${COLOR_BOLD}[FAIL]${COLOR_RESET}"
            ;;
        INFO)
            badge="${COLOR_BCYAN}${COLOR_BOLD}[INFO]${COLOR_RESET}"
            ;;
        SUGG)
            badge="${COLOR_BMAGENTA}${COLOR_BOLD}[SUGG]${COLOR_RESET}"
            ;;
        *)
            badge="${COLOR_WHITE}[$check_status]${COLOR_RESET}"
            ;;
    esac

    printf "  %b  ${COLOR_BOLD}%-12s${COLOR_RESET} %s\n" "$badge" "$id" "$title"
    if [[ -n "$details" ]]; then
        echo "$details" | while IFS= read -r line; do
            [[ -n "$line" ]] && printf "        ${COLOR_DIM}↳ %s${COLOR_RESET}\n" "$line"
        done
    fi
}

# Colored visual progress bar for Hardening Index (0-100)
ui_score_bar() {
    local score="$1"
    local int_score=0

    # Extract integer portion
    if [[ "$score" =~ ^[0-9]+ ]]; then
        int_score=${score%%.*}
    fi
    (( int_score < 0 )) && int_score=0
    (( int_score > 100 )) && int_score=100

    local bar_width=30
    local filled=$(( (int_score * bar_width) / 100 ))
    local unfilled=$(( bar_width - filled ))

    local bar_color="${COLOR_BRED}"
    local rating="CRITICAL / VULNERABLE"
    local rating_color="${COLOR_BRED}"

    if (( int_score >= 85 )); then
        bar_color="${COLOR_BGREEN}"
        rating="EXCELLENT / HARDENED"
        rating_color="${COLOR_BGREEN}"
    elif (( int_score >= 70 )); then
        bar_color="${COLOR_BYELLOW}"
        rating="GOOD / ACCEPTABLE"
        rating_color="${COLOR_BYELLOW}"
    elif (( int_score >= 50 )); then
        bar_color="${COLOR_YELLOW}"
        rating="FAIR / NEEDS ATTENTION"
        rating_color="${COLOR_YELLOW}"
    else
        bar_color="${COLOR_BRED}"
        rating="CRITICAL / VULNERABLE"
        rating_color="${COLOR_BRED}"
    fi

    local filled_str=""
    for (( i = 0; i < filled; i++ )); do
        filled_str="${filled_str}█"
    done

    local unfilled_str=""
    for (( i = 0; i < unfilled; i++ )); do
        unfilled_str="${unfilled_str}░"
    done

    printf "  ${COLOR_BOLD}Hardening Index:${COLOR_RESET} [${bar_color}%s${COLOR_RESET}${COLOR_DIM}%s${COLOR_RESET}] ${COLOR_BOLD}%5.1f%%${COLOR_RESET} (${rating_color}%s${COLOR_RESET})\n" \
        "$filled_str" "$unfilled_str" "$score" "$rating"
}

# Status message helpers
ui_info() {
    printf "${COLOR_BCYAN}[INFO]${COLOR_RESET} %s\n" "$1"
}

ui_warn() {
    printf "${COLOR_BYELLOW}[WARN]${COLOR_RESET} %s\n" "$1"
}

ui_error() {
    printf "${COLOR_BRED}[ERROR]${COLOR_RESET} %s\n" "$1" >&2
}

ui_success() {
    printf "${COLOR_BGREEN}[PASS]${COLOR_RESET} %s\n" "$1"
}

# Animated spinner for background tasks
ui_spinner() {
    local pid="$1"
    local message="${2:-Running}"
    local spin_chars=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=1

    # Don't spin if output is redirected or quiet
    if [[ ! -t 1 ]] || [[ "${MACHAR_QUIET:-0}" -eq 1 ]]; then
        wait "$pid"
        return $?
    fi

    tput civis 2>/dev/null || true
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${COLOR_BCYAN}%s${COLOR_RESET} %s..." "${spin_chars[i]}" "$message"
        (( i = (i % ${#spin_chars[@]}) + 1 ))
        sleep 0.08
    done
    wait "$pid"
    local exit_code=$?
    tput cnorm 2>/dev/null || true
    printf "\r\033[K"
    return $exit_code
}

# Auto-initialize colors on load
ui_init_colors
