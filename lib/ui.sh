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

## Initialize or reset ANSI color codes
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
        COLOR_GRAY=""
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
        BG_DARK=""
        COLOR_INV=""
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
        COLOR_GRAY="\033[90m"
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
        BG_DARK="\033[48;5;236m"
        COLOR_INV="\033[7m"
    fi
}

# Explicitly disable colors
ui_disable_colors() {
    MACHAR_NO_COLOR=1
    ui_init_colors
}

# Terminal width detection
ui_get_term_width() {
    local cols
    if [[ "${MACHAR_TERM_WIDTH:-}" =~ ^[0-9]+$ ]] && (( MACHAR_TERM_WIDTH > 0 )); then
        echo "$MACHAR_TERM_WIDTH"
        return 0
    fi
    cols=$(tput cols 2>/dev/null)
    if [[ -z "$cols" || "$cols" -le 0 ]] 2>/dev/null; then
        cols=${COLUMNS:-80}
    fi
    if [[ -z "$cols" || "$cols" -le 0 ]] 2>/dev/null; then
        cols=80
    fi
    echo "$cols"
}

ui_repeat() {
    local char="$1" count="${2:-0}" out="" i
    for (( i = 0; i < count; i++ )); do out+="$char"; done
    print -rn -- "$out"
}

ui_fit_text() {
    local value="$1" width="${2:-1}"
    (( width < 1 )) && width=1
    if (( ${#value} > width )); then
        if (( width > 3 )); then
            value="${value[1,$(( width - 3 ))]}..."
        else
            value="${value[1,$width]}"
        fi
    fi
    printf "%-${width}s" "$value"
}

ui_wrap_text() {
    local prefix="$1" value="$2" width="${3:-$(ui_get_term_width)}"
    local content_width=$(( width - ${#prefix} - 1 ))
    (( content_width < 18 )) && content_width=18
    local continuation=$(printf "%${#prefix}s" "")
    local first=1
    print -r -- "$value" | fold -s -w "$content_width" | while IFS= read -r line; do
        if (( first )); then
            printf "%s%s\n" "$prefix" "$line"
            first=0
        else
            printf "%s%s\n" "$continuation" "$line"
        fi
    done
}

ui_labeled_text() {
    local label="$1" value="$2" color="$3" width="${4:-$(ui_get_term_width)}"
    local lead="        ${label}  "
    local continuation="        $(printf "%${#label}s" "")  "
    local content_width=$(( width - ${#lead} - 1 ))
    (( content_width < 18 )) && content_width=18
    local first=1
    print -r -- "$value" | fold -s -w "$content_width" | while IFS= read -r line; do
        if (( first )); then
            printf "%b%s%s%b\n" "$color" "$lead" "$line" "$COLOR_RESET"
            first=0
        else
            printf "%b%s%s%b\n" "$COLOR_DIM" "$continuation" "$line" "$COLOR_RESET"
        fi
    done
}

ui_panel_title() {
    local title="$1" width=$(ui_get_term_width)
    (( width > 96 )) && width=96
    (( width < 36 )) && width=36
    local inner=$(( width - 2 ))
    local h=$(ui_char border_h) tl=$(ui_char border_round_tl) tr=$(ui_char border_round_tr)
    local bl=$(ui_char border_round_bl) br=$(ui_char border_round_br) v=$(ui_char border_v)
    local line=$(ui_repeat "$h" "$inner") fitted=$(ui_fit_text "  $title" "$inner")
    printf "%b%s%s%s%b\n" "$COLOR_BCYAN" "$tl" "$line" "$tr" "$COLOR_RESET"
    printf "%b%s%b%b%s%b%b%s%b\n" "$COLOR_BCYAN" "$v" "$COLOR_RESET" "$COLOR_BOLD" "$fitted" "$COLOR_RESET" "$COLOR_BCYAN" "$v" "$COLOR_RESET"
    printf "%b%s%s%s%b\n" "$COLOR_BCYAN" "$bl" "$line" "$br" "$COLOR_RESET"
}

ui_rule() {
    local width=$(ui_get_term_width)
    (( width > 96 )) && width=96
    (( width < 8 )) && width=8
    printf "%b%s%b\n" "$COLOR_DIM" "$(ui_repeat "$(ui_char border_h)" "$width")" "$COLOR_RESET"
}

# ASCII or Unicode symbol resolver
ui_char() {
    local sym="$1"
    if [[ "${MACHAR_ASCII:-0}" -eq 1 ]]; then
        case "$sym" in
            bar_full)  echo "#" ;;
            bar_empty) echo "-" ;;
            bullet)    echo ">" ;;
            arrow)     echo "->" ;;
            border_tl) echo "┌" ;;
            border_tr) echo "┐" ;;
            border_bl) echo "└" ;;
            border_br) echo "┘" ;;
            border_round_tl) echo "+" ;;
            border_round_tr) echo "+" ;;
            border_round_bl) echo "+" ;;
            border_round_br) echo "+" ;;
            border_h)  echo "-" ;;
            border_v)  echo "|" ;;
            check)     echo "OK" ;;
            cross)     echo "FAIL" ;;
            warn)      echo "WARN" ;;
            info)      echo "INFO" ;;
            bulb)      echo "SUGG" ;;
            *) echo "$sym" ;;
        esac
    else
        case "$sym" in
            bar_full)  echo "█" ;;
            bar_empty) echo "░" ;;
            bullet)    echo "▶" ;;
            arrow)     echo "↳" ;;
            border_tl) echo "┌" ;;
            border_tr) echo "┐" ;;
            border_bl) echo "└" ;;
            border_br) echo "┘" ;;
            border_round_tl) echo "╭" ;;
            border_round_tr) echo "╮" ;;
            border_round_bl) echo "╰" ;;
            border_round_br) echo "╯" ;;
            border_h)  echo "─" ;;
            border_v)  echo "│" ;;
            check)     echo "✔" ;;
            cross)     echo "✖" ;;
            warn)      echo "▲" ;;
            info)      echo "ℹ" ;;
            bulb)      echo "💡" ;;
            *) echo "$sym" ;;
        esac
    fi
}

# Display ASCII banner with system metadata
ui_banner() {
    local version="${MACHAR_VERSION:-1.3.0}"
    local os_product os_version os_build arch current_time current_user hostname

    os_product="${MACHAR_OS_PRODUCT:-$(sw_vers -productName 2>/dev/null || echo "macOS")}"
    os_version="${MACHAR_OS_VERSION:-$(sw_vers -productVersion 2>/dev/null || echo "Unknown")}"
    os_build="${MACHAR_OS_BUILD:-$(sw_vers -buildVersion 2>/dev/null || echo "Unknown")}"
    arch="${MACHAR_ARCH:-$(uname -m 2>/dev/null || echo "arm64")}"
    current_time="${MACHAR_AUDIT_TIME:-$(date "+%Y-%m-%d %H:%M:%S %Z")}"
    current_user="${MACHAR_USER:-$(id -un 2>/dev/null || whoami)}"
    hostname="${MACHAR_HOSTNAME:-$(hostname -s 2>/dev/null || hostname)}"

    local app_desc="macOS Security Posture"
    local app_sub="CIS Apple • NIST SP 800-53 • MITRE ATT&CK"
    local lbl_host="HOST" lbl_build="SYSTEM" lbl_time="SCAN" lbl_user="USER"

    if [[ "${CURRENT_LANG:-en}" == "tr" ]]; then
        app_desc="macOS Güvenlik Duruşu"
        app_sub="CIS Apple • NIST SP 800-53 • MITRE ATT&CK"
        lbl_host="SİSTEM"
        lbl_build="PLATFORM"
        lbl_time="TARAMA"
        lbl_user="KULLANICI"
    fi

    local term_width=$(ui_get_term_width)
    local width=$term_width
    (( width > 96 )) && width=96
    (( width < 36 )) && width=36
    local inner=$(( width - 2 ))
    local h=$(ui_char border_h) tl=$(ui_char border_round_tl) tr=$(ui_char border_round_tr)
    local bl=$(ui_char border_round_bl) br=$(ui_char border_round_br) v=$(ui_char border_v)
    local line=$(ui_repeat "$h" "$inner")
    local title="MACHARDEN / ${app_desc} / v${version}"
    local row1=$(ui_fit_text "  $title" "$inner")
    local row2=$(ui_fit_text "  $app_sub" "$inner")
    local row3=$(ui_fit_text "  ${lbl_host}  ${hostname}    ${lbl_user}  ${current_user}" "$inner")
    local row4=$(ui_fit_text "  ${lbl_build}  ${os_product} ${os_version} (${os_build}) ${arch}    ${lbl_time}  ${current_time:0:16}" "$inner")

    printf "%b%s%s%s%b\n" "$COLOR_BCYAN" "$tl" "$line" "$tr" "$COLOR_RESET"
    printf "%b%s%b%b%s%b%b%s%b\n" "$COLOR_BCYAN" "$v" "$COLOR_RESET" "$COLOR_BOLD" "$row1" "$COLOR_RESET" "$COLOR_BCYAN" "$v" "$COLOR_RESET"
    printf "%b%s%b%b%s%b%b%s%b\n" "$COLOR_BCYAN" "$v" "$COLOR_RESET" "$COLOR_DIM" "$row2" "$COLOR_RESET" "$COLOR_BCYAN" "$v" "$COLOR_RESET"
    printf "%b%s%b%s%b%s%b\n" "$COLOR_BCYAN" "$v" "$COLOR_RESET" "$row3" "$COLOR_BCYAN" "$v" "$COLOR_RESET"
    printf "%b%s%b%s%b%s%b\n" "$COLOR_BCYAN" "$v" "$COLOR_RESET" "$row4" "$COLOR_BCYAN" "$v" "$COLOR_RESET"
    printf "%b%s%s%s%b\n" "$COLOR_BCYAN" "$bl" "$line" "$br" "$COLOR_RESET"
}

# Section header separator with category badges and modern divider lines
ui_section() {
    local title="$1"
    local icon=""
    if [[ "${MACHAR_ASCII:-0}" -ne 1 ]]; then
        case "${title:l}" in
            *hardening*|*sistem*)     icon="🛡️  " ;;
            *network*|*ağ*)           icon="🌐 " ;;
            *secret*|*gizli*)         icon="🔐 " ;;
            *persistence*|*kalıcılık*)icon="⚡ " ;;
            *drift*|*diff*)           icon="🔄 " ;;
            *compliance*)             icon="📜 " ;;
            *)                        icon="▶ " ;;
        esac
    fi

    local width=$(ui_get_term_width)
    (( width > 96 )) && width=96
    (( width < 72 )) && icon=""
    local heading="${icon}${title}"
    local max_heading=$(( width - 9 ))
    if (( ${#heading} > max_heading )); then
        heading="$(ui_fit_text "$heading" "$max_heading")"
    fi
    local remaining=$(( width - ${#heading} - 5 ))
    (( remaining < 4 )) && remaining=4
    local rule=$(ui_repeat "$(ui_char border_h)" "$remaining")
    echo ""
    printf "%b%s  %s  %b%s%b\n" "$COLOR_BOLD$COLOR_BCYAN" "$(ui_char border_h)" "$heading" "$COLOR_DIM" "$rule" "$COLOR_RESET"
}

# Formatted check result row with status badge, check ID, title, severity tag, and details
# Usage: ui_result <STATUS> <ID> <TITLE> [DETAILS] [WEIGHT] [REMEDIATION]
ui_result() {
    local check_status="${1:u}"
    local id="$2"
    local title="$3"
    local details="${4:-}"
    local weight="${5:-}"
    local remediation="${6:-}"

    local badge=""
    if [[ "${CURRENT_LANG:-en}" == "tr" ]]; then
        if [[ "${MACHAR_ASCII:-0}" -eq 1 ]]; then
            case "$check_status" in
                PASS) badge="${COLOR_BGREEN}${COLOR_BOLD}[BAŞARILI]${COLOR_RESET}" ;;
                WARN) badge="${COLOR_BYELLOW}${COLOR_BOLD}[UYARI]${COLOR_RESET}" ;;
                FAIL) badge="${COLOR_BRED}${COLOR_BOLD}[BAŞARISIZ]${COLOR_RESET}" ;;
                INFO) badge="${COLOR_BCYAN}${COLOR_BOLD}[BİLGİ]${COLOR_RESET}" ;;
                SUGG) badge="${COLOR_BMAGENTA}${COLOR_BOLD}[ÖNERİ]${COLOR_RESET}" ;;
                *)    badge="${COLOR_WHITE}[$check_status]${COLOR_RESET}" ;;
            esac
        else
            case "$check_status" in
                PASS) badge="${COLOR_BGREEN}${COLOR_BOLD}[✔ BAŞARILI]${COLOR_RESET}" ;;
                WARN) badge="${COLOR_BYELLOW}${COLOR_BOLD}[▲ UYARI]${COLOR_RESET}" ;;
                FAIL) badge="${COLOR_BRED}${COLOR_BOLD}[✖ BAŞARISIZ]${COLOR_RESET}" ;;
                INFO) badge="${COLOR_BCYAN}${COLOR_BOLD}[ℹ BİLGİ]${COLOR_RESET}" ;;
                SUGG) badge="${COLOR_BMAGENTA}${COLOR_BOLD}[💡 ÖNERİ]${COLOR_RESET}" ;;
                *)    badge="${COLOR_WHITE}[$check_status]${COLOR_RESET}" ;;
            esac
        fi
        title=$(i18n_get_check_title "$id" "$title")
        details=$(i18n_get_check_details "$id" "$check_status" "$details")
    else
        if [[ "${MACHAR_ASCII:-0}" -eq 1 ]]; then
            case "$check_status" in
                PASS) badge="${COLOR_BGREEN}${COLOR_BOLD}[PASS]${COLOR_RESET}" ;;
                WARN) badge="${COLOR_BYELLOW}${COLOR_BOLD}[WARN]${COLOR_RESET}" ;;
                FAIL) badge="${COLOR_BRED}${COLOR_BOLD}[FAIL]${COLOR_RESET}" ;;
                INFO) badge="${COLOR_BCYAN}${COLOR_BOLD}[INFO]${COLOR_RESET}" ;;
                SUGG) badge="${COLOR_BMAGENTA}${COLOR_BOLD}[SUGG]${COLOR_RESET}" ;;
                *)    badge="${COLOR_WHITE}[$check_status]${COLOR_RESET}" ;;
            esac
        else
            case "$check_status" in
                PASS) badge="${COLOR_BGREEN}${COLOR_BOLD}[✔ PASS]${COLOR_RESET}" ;;
                WARN) badge="${COLOR_BYELLOW}${COLOR_BOLD}[▲ WARN]${COLOR_RESET}" ;;
                FAIL) badge="${COLOR_BRED}${COLOR_BOLD}[✖ FAIL]${COLOR_RESET}" ;;
                INFO) badge="${COLOR_BCYAN}${COLOR_BOLD}[ℹ INFO]${COLOR_RESET}" ;;
                SUGG) badge="${COLOR_BMAGENTA}${COLOR_BOLD}[💡 SUGG]${COLOR_RESET}" ;;
                *)    badge="${COLOR_WHITE}[$check_status]${COLOR_RESET}" ;;
            esac
        fi
    fi

    local sev_badge=""
    if [[ -n "$weight" ]]; then
        local int_w=5
        [[ "$weight" =~ ^[0-9]+ ]] && int_w=${weight%%.*}
        if (( int_w >= 9 )); then
            sev_badge="${COLOR_BRED}${COLOR_BOLD}[CRITICAL]${COLOR_RESET}"
        elif (( int_w >= 7 )); then
            sev_badge="${COLOR_RED}${COLOR_BOLD}[HIGH]${COLOR_RESET}"
        elif (( int_w >= 5 )); then
            sev_badge="${COLOR_BYELLOW}[MEDIUM]${COLOR_RESET}"
        else
            sev_badge="${COLOR_DIM}[LOW]${COLOR_RESET}"
        fi
    fi

    local term_width=$(ui_get_term_width)
    if (( term_width < 72 )); then
        if [[ -n "$sev_badge" && ("$check_status" == "FAIL" || "$check_status" == "WARN") ]]; then
            printf "  %b  ${COLOR_BOLD}${COLOR_BCYAN}%s${COLOR_RESET}  %b\n" "$badge" "$id" "$sev_badge"
        else
            printf "  %b  ${COLOR_BOLD}${COLOR_BCYAN}%s${COLOR_RESET}\n" "$badge" "$id"
        fi
        ui_wrap_text "      " "$title" "$term_width"
    elif [[ -n "$sev_badge" && ("$check_status" == "FAIL" || "$check_status" == "WARN") ]]; then
        printf "  %b  ${COLOR_BOLD}${COLOR_BCYAN}%-10s${COLOR_RESET} %s  %b\n" "$badge" "$id" "$title" "$sev_badge"
    else
        printf "  %b  ${COLOR_BOLD}${COLOR_BCYAN}%-10s${COLOR_RESET} %s\n" "$badge" "$id" "$title"
    fi

    if [[ -n "$details" ]]; then
        local arrow_sym=$(ui_char arrow)
        ui_wrap_text "        ${arrow_sym} " "$details" "$term_width" | while IFS= read -r line; do
            printf "${COLOR_DIM}%s${COLOR_RESET}\n" "$line"
        done
    fi

    if [[ -n "$remediation" && ("$check_status" == "FAIL" || "$check_status" == "WARN") ]]; then
        local fix_lbl="ACTION" fix_color="$COLOR_BCYAN"
        if [[ "$remediation" == "[GUIDE] "* ]]; then
            remediation="${remediation#\[GUIDE\] }"
            fix_lbl="GUIDE"
            [[ "${CURRENT_LANG:-en}" == "tr" ]] && fix_lbl="REHBER"
            fix_color="$COLOR_BYELLOW"
        elif [[ "$remediation" == "[EXEC] "* ]]; then
            remediation="${remediation#\[EXEC\] }"
            [[ "${CURRENT_LANG:-en}" == "tr" ]] && fix_lbl="KOMUT"
        else
            [[ "${CURRENT_LANG:-en}" == "tr" ]] && fix_lbl="EYLEM"
        fi
        ui_labeled_text "$fix_lbl" "$remediation" "$fix_color" "$term_width"
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

    local term_width=$(ui_get_term_width)
    local bar_width=32
    if (( term_width < 52 )); then
        bar_width=10
    elif (( term_width < 72 )); then
        bar_width=16
    elif (( term_width < 96 )); then
        bar_width=24
    fi

    local filled=$(( (int_score * bar_width) / 100 ))
    local unfilled=$(( bar_width - filled ))
    (( filled < 0 )) && filled=0
    (( unfilled < 0 )) && unfilled=0

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

    local sym_full=$(ui_char bar_full)
    local sym_empty=$(ui_char bar_empty)

    local filled_str=""
    for (( i = 0; i < filled; i++ )); do
        filled_str="${filled_str}${sym_full}"
    done

    local unfilled_str=""
    for (( i = 0; i < unfilled; i++ )); do
        unfilled_str="${unfilled_str}${sym_empty}"
    done

    if (( term_width < 72 )); then
        printf "  ${COLOR_BOLD}%s${COLOR_RESET} [${bar_color}%s${COLOR_RESET}${COLOR_DIM}%s${COLOR_RESET}] ${COLOR_BOLD}%5.1f%%${COLOR_RESET}\n" \
            "$bar_label" "$filled_str" "$unfilled_str" "$score"
        printf "  ${rating_color}%s${COLOR_RESET}\n" "$rating"
    else
        printf "  ${COLOR_BOLD}%s${COLOR_RESET} [${bar_color}%s${COLOR_RESET}${COLOR_DIM}%s${COLOR_RESET}] ${COLOR_BOLD}%5.1f%%${COLOR_RESET} (${rating_color}%s${COLOR_RESET})\n" \
            "$bar_label" "$filled_str" "$unfilled_str" "$score" "$rating"
    fi
}

# Adaptive category score row. Neutral-only categories use N/A instead of a false zero.
# Usage: ui_category_score_row <category_name> <score_percent|N/A> <passed> <warn> <fail> [info] [suggestions]
ui_category_score_row() {
    local cat_name="$1"
    local score="${2:-0.0}"
    local passed="${3:-0}"
    local warn="${4:-0}"
    local fail="${5:-0}"
    local info="${6:-0}"
    local sugg="${7:-0}"

    score="${score%%%}"
    local is_na=0
    [[ "$score" == "N/A" ]] && is_na=1
    local int_score=0
    if [[ "$score" =~ ^[0-9]+ ]]; then
        int_score=${score%%.*}
    fi
    (( int_score < 0 )) && int_score=0
    (( int_score > 100 )) && int_score=100

    local term_width=$(ui_get_term_width)
    local bar_width=15
    (( term_width < 72 )) && bar_width=10
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

    local sym_full=$(ui_char bar_full)
    local sym_empty=$(ui_char bar_empty)

    local filled_str=""
    local i
    for (( i = 0; i < filled; i++ )); do
        filled_str="${filled_str}${sym_full}"
    done

    local unfilled_str=""
    for (( i = 0; i < unfilled; i++ )); do
        unfilled_str="${unfilled_str}${sym_empty}"
    done

    local score_num=0.0
    if [[ "$score" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        score_num="$score"
    fi

    local pass_lbl="PASS"
    local warn_lbl="WARN"
    local fail_lbl="FAIL"
    local info_lbl="INFO"
    local sugg_lbl="SUGG"
    local cat_width=14
    if [[ "${CURRENT_LANG:-en}" == "tr" ]]; then
        pass_lbl="$(i18n_t "ui.status.pass" "BAŞARILI")"
        warn_lbl="$(i18n_t "ui.status.warn" "UYARI")"
        fail_lbl="$(i18n_t "ui.status.fail" "BAŞARISIZ")"
        info_lbl="$(i18n_t "ui.status.info" "BİLGİ")"
        sugg_lbl="$(i18n_t "ui.status.sugg" "ÖNERİ")"
        cat_width=34
    fi

    local score_display neutral=""
    if (( is_na )); then
        score_display="  N/A "
        bar_color="$COLOR_DIM"
    else
        score_display=$(printf "%5.1f%%" "$score_num")
    fi
    (( info > 0 )) && neutral+="  ${info} ${info_lbl}"
    (( sugg > 0 )) && neutral+="  ${sugg} ${sugg_lbl}"

    if (( term_width < 72 )); then
        printf "  ${COLOR_BOLD}%s${COLOR_RESET}\n" "$cat_name"
        printf "    [${bar_color}%s${COLOR_RESET}${COLOR_DIM}%s${COLOR_RESET}] ${COLOR_BOLD}%s${COLOR_RESET}\n" "$filled_str" "$unfilled_str" "$score_display"
        printf "    ${COLOR_BGREEN}${COLOR_BOLD}[%d ${pass_lbl}]${COLOR_RESET} ${COLOR_BYELLOW}${COLOR_BOLD}[%d ${warn_lbl}]${COLOR_RESET} ${COLOR_BRED}${COLOR_BOLD}[%d ${fail_lbl}]${COLOR_RESET}${COLOR_DIM}%s${COLOR_RESET}\n" \
            "$passed" "$warn" "$fail" "$neutral"
    elif (( term_width < 100 )); then
        printf "  ${COLOR_BOLD}%s${COLOR_RESET}\n" "$cat_name"
        printf "    [${bar_color}%s${COLOR_RESET}${COLOR_DIM}%s${COLOR_RESET}] ${COLOR_BOLD}%s${COLOR_RESET}  ${COLOR_BGREEN}${COLOR_BOLD}[%d ${pass_lbl}]${COLOR_RESET} ${COLOR_BYELLOW}${COLOR_BOLD}[%d ${warn_lbl}]${COLOR_RESET} ${COLOR_BRED}${COLOR_BOLD}[%d ${fail_lbl}]${COLOR_RESET}${COLOR_DIM}%s${COLOR_RESET}\n" \
            "$filled_str" "$unfilled_str" "$score_display" "$passed" "$warn" "$fail" "$neutral"
    else
        printf "  ${COLOR_BOLD}%-${cat_width}s${COLOR_RESET} [${bar_color}%s${COLOR_RESET}${COLOR_DIM}%s${COLOR_RESET}] ${COLOR_BOLD}%s${COLOR_RESET}  ${COLOR_BGREEN}${COLOR_BOLD}[%d ${pass_lbl}]${COLOR_RESET} ${COLOR_BYELLOW}${COLOR_BOLD}[%d ${warn_lbl}]${COLOR_RESET} ${COLOR_BRED}${COLOR_BOLD}[%d ${fail_lbl}]${COLOR_RESET}${COLOR_DIM}%s${COLOR_RESET}\n" \
            "$cat_name" "$filled_str" "$unfilled_str" "$score_display" "$passed" "$warn" "$fail" "$neutral"
    fi
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

    local tl=$(ui_char border_tl)
    local tr=$(ui_char border_tr)
    local bl=$(ui_char border_bl)
    local br=$(ui_char border_br)
    local h_char=$(ui_char border_h)
    local v_char=$(ui_char border_v)

    local term_width=$(ui_get_term_width)
    if (( term_width < 72 )); then
        printf "  %b%s: %s (%s%%)%b\n" "${grade_color}${COLOR_BOLD}" "${grade_word}" "${letter_grade}" "${score_fmt}" "${COLOR_RESET}"
        printf "  %b%s%b\n" "${grade_color}" "${rating_text}" "${COLOR_RESET}"
        return 0
    fi

    local hline=""
    for (( i = 0; i < inner_len; i++ )); do
        hline="${hline}${h_char}"
    done

    printf "  %b%s%s%s%b\n" "${border_color}" "${tl}" "${hline}" "${tr}" "${COLOR_RESET}"
    printf "  %b%s%b  ${COLOR_BOLD}%s: %b%s%b (%s%%)  ${COLOR_DIM}•${COLOR_RESET}  %b%s%b  %s%b%s%b\n" \
        "${border_color}" "${v_char}" "${COLOR_RESET}" \
        "${grade_word}" \
        "${grade_color}" "${letter_grade}" "${COLOR_RESET}" \
        "${score_fmt}" \
        "${grade_color}" "${rating_text}" "${COLOR_RESET}" \
        "${pad_right}" \
        "${border_color}" "${v_char}" "${COLOR_RESET}"
    printf "  %b%s%s%s%b\n" "${border_color}" "${bl}" "${hline}" "${br}" "${COLOR_RESET}"
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
