#!/bin/zsh
# ==============================================================================
# macharden - lib/ui.sh
# Terminal UI, ANSI styling, ASCII banners, status indicators, and progress bars
# ==============================================================================

# Ensure i18n functions are available
if ! typeset -f i18n_t >/dev/null 2>&1; then
    _ui_lib_dir="${0:A:h}"
    if [[ -f "${_ui_lib_dir}/i18n.sh" ]]; then
        source "${_ui_lib_dir}/i18n.sh"
    elif [[ -f "./lib/i18n.sh" ]]; then
        source "./lib/i18n.sh"
    elif [[ -f "../lib/i18n.sh" ]]; then
        source "../lib/i18n.sh"
    fi
fi

if ! typeset -f i18n_t >/dev/null 2>&1; then
    i18n_t() { echo "${2:-$1}"; }
    i18n_get_check_title() { echo "${2:-$1}"; }
    i18n_get_check_details() { echo "${3:-$1}"; }
    i18n_get_category_name() { echo "$1"; }
    i18n_get_rating_text() {
        local score="${1:-0}"
        local s=0
        [[ "$score" =~ ^[0-9]+ ]] && s=${score%%.*}
        if (( s >= 85 )); then echo "EXCELLENT / HARDENED"
        elif (( s >= 70 )); then echo "GOOD / ACCEPTABLE"
        elif (( s >= 50 )); then echo "FAIR / NEEDS ATTENTION"
        else echo "CRITICAL / VULNERABLE"; fi
    }
fi

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
    local version="${MACHAR_VERSION:-1.2.0}"
    local os_product os_version os_build arch current_time current_user hostname

    os_product=$(sw_vers -productName 2>/dev/null || echo "macOS")
    os_version=$(sw_vers -productVersion 2>/dev/null || echo "Unknown")
    os_build=$(sw_vers -buildVersion 2>/dev/null || echo "Unknown")
    arch=$(uname -m 2>/dev/null || echo "arm64")
    current_time=$(date "+%Y-%m-%d %H:%M:%S %Z")
    current_user=$(id -un 2>/dev/null || whoami)
    hostname=$(hostname -s 2>/dev/null || hostname)

    local app_desc="  macOS Security Hardening & Audit Scanner  v${version}"
    local lbl_host="Target Host:"
    local lbl_build="macOS Build:"
    local lbl_time="Audit Time:"

    if [[ "${CURRENT_LANG:-en}" == "tr" ]]; then
        app_desc="  $(i18n_t "ui.app_desc" "macOS Güvenlik Sıkılaştırma ve Denetim Tarayıcısı")  v${version}"
        lbl_host="$(i18n_t "ui.kpi.target_host" "Hedef Sistem:")"
        lbl_build="$(i18n_t "ui.kpi.macos_build" "macOS Sürümü:")"
        lbl_time="$(i18n_t "ui.kpi.audit_time" "Denetim Zamanı:")"
    fi

    cat <<EOF
${COLOR_BCYAN}                   _                     _            ${COLOR_RESET}
${COLOR_BCYAN}  _ __ ___   __ _  ___| |__   __ _ _ __   __| | ___ _ __  ${COLOR_RESET}
${COLOR_BCYAN} | '_ \` _ \ / _\` |/ __| '_ \ / _\` | '__| / _\` |/ _ \ '_ \ ${COLOR_RESET}
${COLOR_BCYAN} | | | | | | (_| | (__| | | | (_| | |   | (_| |  __/ | | |${COLOR_RESET}
${COLOR_BCYAN} |_| |_| |_|\__,_|\___|_| |_|\__,_|_|    \__,_|\___|_| |_|${COLOR_RESET}
${COLOR_DIM}${app_desc}${COLOR_RESET}
${COLOR_DIM}──────────────────────────────────────────────────────────────────────${COLOR_RESET}
 ${COLOR_BOLD}${lbl_host}${COLOR_RESET}   ${COLOR_WHITE}${hostname}${COLOR_RESET} (${COLOR_DIM}${current_user}${COLOR_RESET})
 ${COLOR_BOLD}${lbl_build}${COLOR_RESET}   ${COLOR_WHITE}${os_product} ${os_version} (Build ${os_build}) [${arch}]${COLOR_RESET}
 ${COLOR_BOLD}${lbl_time}${COLOR_RESET}    ${COLOR_WHITE}${current_time}${COLOR_RESET}
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
    if [[ "${CURRENT_LANG:-en}" == "tr" ]]; then
        case "$check_status" in
            PASS)
                badge="${COLOR_BGREEN}${COLOR_BOLD}[$(i18n_t "ui.status.pass" "BAŞARILI")]${COLOR_RESET}"
                ;;
            WARN)
                badge="${COLOR_BYELLOW}${COLOR_BOLD}[$(i18n_t "ui.status.warn" "UYARI")]${COLOR_RESET}"
                ;;
            FAIL)
                badge="${COLOR_BRED}${COLOR_BOLD}[$(i18n_t "ui.status.fail" "BAŞARISIZ")]${COLOR_RESET}"
                ;;
            INFO)
                badge="${COLOR_BCYAN}${COLOR_BOLD}[$(i18n_t "ui.status.info" "BİLGİ")]${COLOR_RESET}"
                ;;
            SUGG)
                badge="${COLOR_BMAGENTA}${COLOR_BOLD}[$(i18n_t "ui.status.sugg" "ÖNERİ")]${COLOR_RESET}"
                ;;
            *)
                badge="${COLOR_WHITE}[$check_status]${COLOR_RESET}"
                ;;
        esac
        title=$(i18n_get_check_title "$id" "$title")
        details=$(i18n_get_check_details "$id" "$check_status" "$details")
    else
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
    fi

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
    local bar_label="Hardening Index:"

    if [[ "${CURRENT_LANG:-en}" == "tr" ]]; then
        rating=$(i18n_get_rating_text "$score")
        bar_label="$(i18n_t "ui.hardening_index" "Sıkılaştırma İndeksi"):"
    fi

    if (( int_score >= 85 )); then
        bar_color="${COLOR_BGREEN}"
        [[ "${CURRENT_LANG:-en}" != "tr" ]] && rating="EXCELLENT / HARDENED"
        rating_color="${COLOR_BGREEN}"
    elif (( int_score >= 70 )); then
        bar_color="${COLOR_BYELLOW}"
        [[ "${CURRENT_LANG:-en}" != "tr" ]] && rating="GOOD / ACCEPTABLE"
        rating_color="${COLOR_BYELLOW}"
    elif (( int_score >= 50 )); then
        bar_color="${COLOR_YELLOW}"
        [[ "${CURRENT_LANG:-en}" != "tr" ]] && rating="FAIR / NEEDS ATTENTION"
        rating_color="${COLOR_YELLOW}"
    else
        bar_color="${COLOR_BRED}"
        [[ "${CURRENT_LANG:-en}" != "tr" ]] && rating="CRITICAL / VULNERABLE"
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

    printf "  ${COLOR_BOLD}%s${COLOR_RESET} [${bar_color}%s${COLOR_RESET}${COLOR_DIM}%s${COLOR_RESET}] ${COLOR_BOLD}%5.1f%%${COLOR_RESET} (${rating_color}%s${COLOR_RESET})\n" \
        "$bar_label" "$filled_str" "$unfilled_str" "$score" "$rating"
}

# Visually aligned category score row with a colored 15-char progress bar and pass/warn/fail badges
# Usage: ui_category_score_row <category_name> <score_percent> <passed> <warn> <fail>
ui_category_score_row() {
    local cat_name="$1"
    local score="${2:-0.0}"
    local passed="${3:-0}"
    local warn="${4:-0}"
    local fail="${5:-0}"

    # Strip trailing percent symbol if present
    score="${score%%%}"

    local int_score=0
    if [[ "$score" =~ ^[0-9]+ ]]; then
        int_score=${score%%.*}
    fi
    (( int_score < 0 )) && int_score=0
    (( int_score > 100 )) && int_score=100

    local bar_width=15
    local filled=$(( (int_score * bar_width) / 100 ))
    local unfilled=$(( bar_width - filled ))
    (( filled < 0 )) && filled=0
    (( unfilled < 0 )) && unfilled=0

    local bar_color="${COLOR_BRED}"
    if (( int_score >= 85 )); then
        bar_color="${COLOR_BGREEN}"
    elif (( int_score >= 70 )); then
        bar_color="${COLOR_BYELLOW}"
    elif (( int_score >= 50 )); then
        bar_color="${COLOR_YELLOW}"
    else
        bar_color="${COLOR_BRED}"
    fi

    local filled_str=""
    local i
    for (( i = 0; i < filled; i++ )); do
        filled_str="${filled_str}█"
    done

    local unfilled_str=""
    for (( i = 0; i < unfilled; i++ )); do
        unfilled_str="${unfilled_str}░"
    done

    local score_num=0.0
    if [[ "$score" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        score_num="$score"
    fi

    local pass_lbl="PASS"
    local warn_lbl="WARN"
    local fail_lbl="FAIL"
    local cat_width=14
    if [[ "${CURRENT_LANG:-en}" == "tr" ]]; then
        pass_lbl="$(i18n_t "ui.status.pass" "BAŞARILI")"
        warn_lbl="$(i18n_t "ui.status.warn" "UYARI")"
        fail_lbl="$(i18n_t "ui.status.fail" "BAŞARISIZ")"
        cat_width=34
    fi

    printf "  ${COLOR_BOLD}%-${cat_width}s${COLOR_RESET} [${bar_color}%s${COLOR_RESET}${COLOR_DIM}%s${COLOR_RESET}] ${COLOR_BOLD}%5.1f%%${COLOR_RESET}  ${COLOR_BGREEN}${COLOR_BOLD}[%d ${pass_lbl}]${COLOR_RESET} ${COLOR_BYELLOW}${COLOR_BOLD}[%d ${warn_lbl}]${COLOR_RESET} ${COLOR_BRED}${COLOR_BOLD}[%d ${fail_lbl}]${COLOR_RESET}\n" \
        "$cat_name" "$filled_str" "$unfilled_str" "$score_num" "$passed" "$warn" "$fail"
}

# Clean bordered ASCII box displaying overall grade and rating
# Usage: ui_grade_box <score> <letter_grade> <rating_text>
ui_grade_box() {
    local score="${1:-0.0}"
    local letter_grade="${2:-}"
    local rating_text="${3:-}"

    # Strip trailing percent symbol if present
    score="${score%%%}"

    local int_score=0
    if [[ "$score" =~ ^[0-9]+ ]]; then
        int_score=${score%%.*}
    fi
    (( int_score < 0 )) && int_score=0
    (( int_score > 100 )) && int_score=100

    if [[ -z "$letter_grade" ]]; then
        if (( int_score >= 95 )); then
            letter_grade="A+"
        elif (( int_score >= 90 )); then
            letter_grade="A"
        elif (( int_score >= 80 )); then
            letter_grade="B+"
        elif (( int_score >= 70 )); then
            letter_grade="B"
        elif (( int_score >= 60 )); then
            letter_grade="C"
        elif (( int_score >= 50 )); then
            letter_grade="D"
        else
            letter_grade="F"
        fi
    fi

    if [[ -z "$rating_text" ]]; then
        if typeset -f i18n_get_rating_text >/dev/null 2>&1; then
            rating_text=$(i18n_get_rating_text "$score")
        elif (( int_score >= 85 )); then
            rating_text="EXCELLENT / HARDENED"
        elif (( int_score >= 70 )); then
            rating_text="GOOD / ACCEPTABLE"
        elif (( int_score >= 50 )); then
            rating_text="FAIR / NEEDS ATTENTION"
        else
            rating_text="CRITICAL / VULNERABLE"
        fi
    fi

    local score_fmt
    if [[ "$score" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        score_fmt=$(printf "%.1f" "$score")
    else
        score_fmt="$score"
    fi

    local grade_color="${COLOR_BRED}"
    local border_color="${COLOR_BRED}"
    if (( int_score >= 85 )); then
        grade_color="${COLOR_BGREEN}"
        border_color="${COLOR_BGREEN}"
    elif (( int_score >= 70 )); then
        grade_color="${COLOR_BYELLOW}"
        border_color="${COLOR_BYELLOW}"
    elif (( int_score >= 50 )); then
        grade_color="${COLOR_YELLOW}"
        border_color="${COLOR_YELLOW}"
    else
        grade_color="${COLOR_BRED}"
        border_color="${COLOR_BRED}"
    fi

    local grade_word="GRADE"
    if [[ "${CURRENT_LANG:-en}" == "tr" ]]; then
        grade_word="$(i18n_t "ui.grade" "DERECE")"
    fi

    local text="  ${grade_word}: ${letter_grade} (${score_fmt}%)  •  ${rating_text}  "
    local inner_len=${#text}
    if (( inner_len < 42 )); then
        inner_len=42
    fi

    local diff=$(( inner_len - ${#text} ))
    local pad_right=""
    local i
    for (( i = 0; i < diff; i++ )); do
        pad_right="${pad_right} "
    done

    local hline=""
    for (( i = 0; i < inner_len; i++ )); do
        hline="${hline}─"
    done

    printf "  %b┌%s┐%b\n" "${border_color}" "${hline}" "${COLOR_RESET}"
    printf "  %b│%b  ${COLOR_BOLD}%s: %b%s%b (%s%%)  ${COLOR_DIM}•${COLOR_RESET}  %b%s%b  %s%b│%b\n" \
        "${border_color}" "${COLOR_RESET}" \
        "${grade_word}" \
        "${grade_color}" "${letter_grade}" "${COLOR_RESET}" \
        "${score_fmt}" \
        "${grade_color}" "${rating_text}" "${COLOR_RESET}" \
        "${pad_right}" \
        "${border_color}" "${COLOR_RESET}"
    printf "  %b└%s┘%b\n" "${border_color}" "${hline}" "${COLOR_RESET}"
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
