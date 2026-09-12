#!/bin/zsh
# ==============================================================================
# macharden - lib/report.sh
# Multi-format reporting engine: Terminal summary, GitHub Markdown, and JSON
# ==============================================================================

# Ensure i18n functions are available
if ! typeset -f i18n_t >/dev/null 2>&1; then
    _rep_lib_dir="${0:A:h}"
    if [[ -f "${_rep_lib_dir}/i18n.sh" ]]; then
        source "${_rep_lib_dir}/i18n.sh"
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

# Helper to determine human-readable rating from score
_get_rating_text() {
    local score="$1"
    if typeset -f i18n_get_rating_text >/dev/null 2>&1; then
        i18n_get_rating_text "$score"
        return 0
    fi
    local int_score=0
    if [[ "$score" =~ ^[0-9]+ ]]; then
        int_score=${score%%.*}
    fi
    if (( int_score >= 85 )); then
        echo "EXCELLENT / HARDENED"
    elif (( int_score >= 70 )); then
        echo "GOOD / ACCEPTABLE"
    elif (( int_score >= 50 )); then
        echo "FAIR / NEEDS ATTENTION"
    else
        echo "CRITICAL / VULNERABLE"
    fi
}

# Helper to determine letter grade from score
_get_letter_grade() {
    local score="${1:-0}"
    local int_score=0
    if [[ "$score" =~ ^[0-9]+ ]]; then
        int_score=${score%%.*}
    fi
    if (( int_score >= 95 )); then
        echo "A+"
    elif (( int_score >= 90 )); then
        echo "A"
    elif (( int_score >= 80 )); then
        echo "B+"
    elif (( int_score >= 70 )); then
        echo "B"
    elif (( int_score >= 60 )); then
        echo "C"
    elif (( int_score >= 50 )); then
        echo "D"
    else
        echo "F"
    fi
}

# Helper to determine severity level tag from weight
# CRITICAL: weight >= 9, HIGH: weight 7-8, MEDIUM: weight 5-6, LOW: weight <= 4
_get_severity_tag() {
    local weight="${1:-5}"
    local int_w=5
    if [[ "$weight" =~ ^[0-9]+ ]]; then
        int_w=${weight%%.*}
    fi
    if (( int_w >= 9 )); then
        echo "CRITICAL"
    elif (( int_w >= 7 )); then
        echo "HIGH"
    elif (( int_w >= 5 )); then
        echo "MEDIUM"
    else
        echo "LOW"
    fi
}


# Terminal executive report
report_terminal() {
    local is_tr=0
    [[ "${CURRENT_LANG:-en}" == "tr" ]] && is_tr=1

    echo ""
    echo "${COLOR_BOLD}${COLOR_BCYAN}======================================================================${COLOR_RESET}"
    if (( is_tr )); then
        echo "                     ${COLOR_BOLD}$(i18n_t "ui.executive_summary_title" "YÖNETİCİ DENETİM ÖZETİ")${COLOR_RESET}"
    else
        echo "                     ${COLOR_BOLD}EXECUTIVE AUDIT SUMMARY${COLOR_RESET}"
    fi
    echo "${COLOR_BOLD}${COLOR_BCYAN}======================================================================${COLOR_RESET}"
    echo ""

    local letter_grade
    letter_grade=$(_get_letter_grade "$HARDENING_INDEX")
    local rating_text
    rating_text=$(_get_rating_text "$HARDENING_INDEX")

    ui_grade_box "$HARDENING_INDEX" "$letter_grade" "$rating_text"
    echo ""

    ui_score_bar "$HARDENING_INDEX"
    echo ""

    if (( is_tr )); then
        printf "  ${COLOR_BOLD}%-28s${COLOR_RESET} %s\n" "$(i18n_t "ui.kpi.total_checks" "Denetlenen Toplam Kontrol:")" "${COLOR_BOLD}${COUNT_TOTAL}${COLOR_RESET}"
        printf "  ${COLOR_BOLD}%-28s${COLOR_RESET} %b\n" "$(i18n_t "ui.kpi.passed_checks" "Başarılı Kontroller:")" "${COLOR_BGREEN}${COUNT_PASS}${COLOR_RESET}"
        printf "  ${COLOR_BOLD}%-28s${COLOR_RESET} %b\n" "$(i18n_t "ui.kpi.warnings" "Uyarılar:")" "${COLOR_BYELLOW}${COUNT_WARN}${COLOR_RESET}"
        printf "  ${COLOR_BOLD}%-28s${COLOR_RESET} %b\n" "$(i18n_t "ui.kpi.failed_checks" "Başarısız Kontroller:")" "${COLOR_BRED}${COUNT_FAIL}${COLOR_RESET}"
        printf "  ${COLOR_BOLD}%-28s${COLOR_RESET} %b\n" "$(i18n_t "ui.kpi.informational" "Bilgilendirme:")" "${COLOR_BCYAN}${COUNT_INFO}${COLOR_RESET}"
        printf "  ${COLOR_BOLD}%-28s${COLOR_RESET} %b\n" "$(i18n_t "ui.kpi.suggestions" "Öneriler:")" "${COLOR_BMAGENTA}${COUNT_SUGG}${COLOR_RESET}"
        printf "  ${COLOR_BOLD}%-28s${COLOR_RESET} %.1f / %.1f\n" "$(i18n_t "ui.kpi.points_earned" "Kazanılan Skor Puanı:")" "$EARNED_POINTS" "$TOTAL_POSSIBLE_POINTS"
    else
        printf "  ${COLOR_BOLD}%-24s${COLOR_RESET} %s\n" "Total Checks Audited:" "${COLOR_BOLD}${COUNT_TOTAL}${COLOR_RESET}"
        printf "  ${COLOR_BOLD}%-24s${COLOR_RESET} %b\n" "Passed Checks:" "${COLOR_BGREEN}${COUNT_PASS}${COLOR_RESET}"
        printf "  ${COLOR_BOLD}%-24s${COLOR_RESET} %b\n" "Warnings:" "${COLOR_BYELLOW}${COUNT_WARN}${COLOR_RESET}"
        printf "  ${COLOR_BOLD}%-24s${COLOR_RESET} %b\n" "Failed Checks:" "${COLOR_BRED}${COUNT_FAIL}${COLOR_RESET}"
        printf "  ${COLOR_BOLD}%-24s${COLOR_RESET} %b\n" "Informational:" "${COLOR_BCYAN}${COUNT_INFO}${COLOR_RESET}"
        printf "  ${COLOR_BOLD}%-24s${COLOR_RESET} %b\n" "Suggestions:" "${COLOR_BMAGENTA}${COUNT_SUGG}${COLOR_RESET}"
        printf "  ${COLOR_BOLD}%-24s${COLOR_RESET} %.1f / %.1f\n" "Score Points Earned:" "$EARNED_POINTS" "$TOTAL_POSSIBLE_POINTS"
    fi
    echo ""

    local n=${#RES_IDS[@]}
    local i=0 j=0

    # Category Posture Breakdown section
    if (( is_tr )); then
        echo "${COLOR_BOLD}${COLOR_BCYAN}▶ $(i18n_t "ui.sections.category_posture_breakdown" "Kategori Bazlı Güvenlik Durumu:")${COLOR_RESET}"
    else
        echo "${COLOR_BOLD}${COLOR_BCYAN}▶ Category Posture Breakdown:${COLOR_RESET}"
    fi
    echo "${COLOR_DIM}----------------------------------------------------------------------${COLOR_RESET}"
    local -a categories=()
    local -A seen_cats=()
    for cat in "${REG_CATEGORIES[@]}"; do
        local cat_key="${cat:l}"
        if [[ -z "${seen_cats[$cat_key]:-}" ]]; then
            seen_cats[$cat_key]=1
            categories+=("${(C)cat}")
        fi
    done
    local cat_name
    for cat_name in "${categories[@]}"; do
        local cat_lower="${cat_name:l}"
        local cat_pass=0
        local cat_warn=0
        local cat_fail=0
        local cat_earned=0.0
        local cat_total=0.0

        for (( j = 1; j <= n; j++ )); do
            local c="${RES_CATEGORIES[j]:l}"
            if [[ "$c" == "$cat_lower" ]]; then
                local st="${RES_STATUSES[j]}"
                local w="${RES_WEIGHTS[j]:-5}"
                [[ "$w" =~ ^[0-9]+(\.[0-9]+)?$ ]] || w=5.0

                case "$st" in
                    PASS)
                        (( ++cat_pass ))
                        cat_total=$(( cat_total + w ))
                        cat_earned=$(( cat_earned + w ))
                        ;;
                    WARN)
                        (( ++cat_warn ))
                        cat_total=$(( cat_total + w ))
                        cat_earned=$(( cat_earned + (w * 0.5) ))
                        ;;
                    FAIL)
                        (( ++cat_fail ))
                        cat_total=$(( cat_total + w ))
                        ;;
                    *)
                        ;;
                esac
            fi
        done

        local cat_score="100.0"
        if (( cat_total > 0.0 )); then
            local raw_score=$(( (cat_earned / cat_total) * 100.0 ))
            cat_score=$(printf "%.1f" "$raw_score")
        elif (( cat_pass + cat_warn + cat_fail == 0 )); then
            cat_score="0.0"
        fi

        local display_cat="$cat_name"
        if (( is_tr )); then
            display_cat=$(i18n_get_category_name "$cat_lower")
        fi
        ui_category_score_row "$display_cat" "$cat_score" "$cat_pass" "$cat_warn" "$cat_fail"
    done
    echo ""

    # Check for FAIL and WARN items
    local has_recs=0
    for (( i = 1; i <= n; i++ )); do
        local st="${RES_STATUSES[i]}"
        if [[ "$st" == "FAIL" || "$st" == "WARN" ]]; then
            has_recs=1
            break
        fi
    done

    if (( has_recs )); then
        if (( is_tr )); then
            echo "${COLOR_BOLD}${COLOR_BYELLOW}▶ $(i18n_t "ui.sections.high_priority_remediation" "Yüksek Öncelikli İyileştirme Eylemleri:")${COLOR_RESET}"
        else
            echo "${COLOR_BOLD}${COLOR_BYELLOW}▶ High Priority Remediation Actions:${COLOR_RESET}"
        fi
        echo "${COLOR_DIM}----------------------------------------------------------------------${COLOR_RESET}"
        
        # Display FAIL items first, then WARN items
        for priority_st in "FAIL" "WARN"; do
            for (( i = 1; i <= n; i++ )); do
                local st="${RES_STATUSES[i]}"
                if [[ "$st" == "$priority_st" ]]; then
                    local id="${RES_IDS[i]}"
                    local cat="${RES_CATEGORIES[i]}"
                    local title="${RES_TITLES[i]}"
                    local weight="${RES_WEIGHTS[i]}"
                    local details="${RES_DETAILS[i]}"
                    local rem="${RES_REMEDIATIONS[i]}"

                    if (( is_tr )); then
                        title=$(i18n_get_check_title "$id" "$title")
                        details=$(i18n_get_check_details "$id" "$st" "$details")
                        cat=$(i18n_get_category_name "$cat")
                    fi

                    local badge=""
                    if [[ "$st" == "FAIL" ]]; then
                        if (( is_tr )); then
                            badge="${COLOR_BRED}${COLOR_BOLD}[$(i18n_t "ui.status.fail" "BAŞARISIZ")]${COLOR_RESET}"
                        else
                            badge="${COLOR_BRED}${COLOR_BOLD}[FAIL]${COLOR_RESET}"
                        fi
                    else
                        if (( is_tr )); then
                            badge="${COLOR_BYELLOW}${COLOR_BOLD}[$(i18n_t "ui.status.warn" "UYARI")]${COLOR_RESET}"
                        else
                            badge="${COLOR_BYELLOW}${COLOR_BOLD}[WARN]${COLOR_RESET}"
                        fi
                    fi

                    local sev_tag=$(_get_severity_tag "$weight")
                    local sev_badge=""
                    local display_sev="$sev_tag"
                    if (( is_tr )); then
                        case "$sev_tag" in
                            CRITICAL)
                                sev_badge="${COLOR_BRED}${COLOR_BOLD}[$(i18n_t "ui.status.critical" "KRİTİK")]${COLOR_RESET}"
                                display_sev="$(i18n_t "ui.status.critical" "KRİTİK")"
                                ;;
                            HIGH)
                                sev_badge="${COLOR_RED}${COLOR_BOLD}[$(i18n_t "ui.status.high" "YÜKSEK")]${COLOR_RESET}"
                                display_sev="$(i18n_t "ui.status.high" "YÜKSEK")"
                                ;;
                            MEDIUM)
                                sev_badge="${COLOR_BYELLOW}${COLOR_BOLD}[$(i18n_t "ui.status.medium" "ORTA")]${COLOR_RESET}"
                                display_sev="$(i18n_t "ui.status.medium" "ORTA")"
                                ;;
                            LOW)
                                sev_badge="${COLOR_BCYAN}${COLOR_BOLD}[$(i18n_t "ui.status.low" "DÜŞÜK")]${COLOR_RESET}"
                                display_sev="$(i18n_t "ui.status.low" "DÜŞÜK")"
                                ;;
                        esac
                    else
                        case "$sev_tag" in
                            CRITICAL) sev_badge="${COLOR_BRED}${COLOR_BOLD}[CRITICAL]${COLOR_RESET}" ;;
                            HIGH)     sev_badge="${COLOR_RED}${COLOR_BOLD}[HIGH]${COLOR_RESET}" ;;
                            MEDIUM)   sev_badge="${COLOR_BYELLOW}${COLOR_BOLD}[MEDIUM]${COLOR_RESET}" ;;
                            LOW)      sev_badge="${COLOR_BCYAN}${COLOR_BOLD}[LOW]${COLOR_RESET}" ;;
                        esac
                    fi

                    if (( is_tr )); then
                        printf "  %b  %b  ${COLOR_BOLD}%-10s${COLOR_RESET} %s ${COLOR_DIM}(Önem: %s, Ağırlık: %s, Kategori: %s)${COLOR_RESET}\n" \
                            "$badge" "$sev_badge" "$id" "$title" "$display_sev" "$weight" "$cat"
                        if [[ -n "$details" ]]; then
                            printf "        ${COLOR_DIM}%s${COLOR_RESET} %s\n" "$(i18n_t "ui.remediation.finding_label" "Bulgu:")" "$details"
                        fi
                        if [[ -n "$rem" ]]; then
                            printf "        ${COLOR_BCYAN}%s${COLOR_RESET}     ${COLOR_WHITE}%s${COLOR_RESET}\n" "$(i18n_t "ui.remediation.fix_label" "Düzeltme:")" "$rem"
                        fi
                    else
                        printf "  %b  %b  ${COLOR_BOLD}%-10s${COLOR_RESET} %s ${COLOR_DIM}(Severity: %s, Weight: %s, Category: %s)${COLOR_RESET}\n" \
                            "$badge" "$sev_badge" "$id" "$title" "$sev_tag" "$weight" "$cat"
                        if [[ -n "$details" ]]; then
                            printf "        ${COLOR_DIM}Finding:${COLOR_RESET} %s\n" "$details"
                        fi
                        if [[ -n "$rem" ]]; then
                            printf "        ${COLOR_BCYAN}Fix:${COLOR_RESET}     ${COLOR_WHITE}%s${COLOR_RESET}\n" "$rem"
                        fi
                    fi
                    echo ""
                fi
            done
        done
        echo "${COLOR_DIM}----------------------------------------------------------------------${COLOR_RESET}"
        if (( is_tr )); then
            printf "  ${COLOR_BOLD}${COLOR_BGREEN}%s${COLOR_RESET}\n" "$(i18n_t "ui.sections.remediation_options" "İyileştirme Seçenekleri:")"
            printf "    • %s\n" "$(i18n_t "ui.remediation.opt_fix" "Kullanılabilir düzeltmeleri etkileşimli olarak uygulamak için --fix ile çalıştırın.")"
            printf "    • %s\n" "$(i18n_t "ui.remediation.opt_gen_fix" "Çalıştırılabilir bir kabuk betiği oluşturmak için --generate-fix [dosya] ile çalıştırın.")"
        else
            printf "  ${COLOR_BOLD}${COLOR_BGREEN}Remediation Options:${COLOR_RESET}\n"
            printf "    • Run with ${COLOR_BOLD}--fix${COLOR_RESET} to interactively apply available remediation fixes.\n"
            printf "    • Run with ${COLOR_BOLD}--generate-fix [file]${COLOR_RESET} to generate an executable shell script.\n"
        fi
    else
        if (( is_tr )); then
            echo "  ${COLOR_BGREEN}${COLOR_BOLD}✔ $(i18n_t "ui.remediation.clean_posture" "Güvenlik duruşu mükemmel. Başarısız kontrol veya uyarı tespit edilmedi.")${COLOR_RESET}"
        else
            echo "  ${COLOR_BGREEN}${COLOR_BOLD}✔ Security posture is excellent. No failed checks or warnings detected.${COLOR_RESET}"
        fi
    fi
    echo ""
}

# Generate GitHub-flavored Markdown report
report_markdown() {
    local output_file="${1:-}"
    local version="${MACHAR_VERSION:-1.3.0}"
    local os_product os_version os_build arch current_time current_user hostname kernel_rel rating

    os_product=$(sw_vers -productName 2>/dev/null || echo "macOS")
    os_version=$(sw_vers -productVersion 2>/dev/null || echo "Unknown")
    os_build=$(sw_vers -buildVersion 2>/dev/null || echo "Unknown")
    arch=$(uname -m 2>/dev/null || echo "arm64")
    kernel_rel=$(uname -r 2>/dev/null || echo "Darwin")
    current_time=$(date "+%Y-%m-%d %H:%M:%S %Z")
    current_user=$(id -un 2>/dev/null || whoami)
    hostname=$(hostname -s 2>/dev/null || hostname)
    rating=$(_get_rating_text "$HARDENING_INDEX")
    local letter_grade
    letter_grade=$(_get_letter_grade "$HARDENING_INDEX")

    local points_display
    points_display=$(printf "%.1f / %.1f" "$EARNED_POINTS" "$TOTAL_POSSIBLE_POINTS")

    local n=${#RES_IDS[@]}
    local i=0 j=0 b=0

    local is_tr=0
    [[ "${CURRENT_LANG:-en}" == "tr" ]] && is_tr=1

    # Build Category Posture Breakdown markdown table
    local cat_table=""
    if (( is_tr )); then
        cat_table+="| $(i18n_t "ui.table_headers.category" "Kategori") | $(i18n_t "ui.table_headers.score" "Skor") | $(i18n_t "ui.table_headers.progress" "İlerleme") | $(i18n_t "ui.table_headers.status" "Durum") | $(i18n_t "ui.table_headers.passed" "Başarılı") | $(i18n_t "ui.table_headers.warnings" "Uyarılar") | $(i18n_t "ui.table_headers.deficiencies" "Eksiklikler") | $(i18n_t "ui.table_headers.points_earned" "Kazanılan Puan") |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
"
    else
        cat_table+="| Category | Score | Progress | Status | Passed | Warnings | Deficiencies | Points Earned |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
"
    fi
    local -a categories=()
    local -A seen_cats=()
    for cat in "${REG_CATEGORIES[@]}"; do
        local cat_key="${cat:l}"
        if [[ -z "${seen_cats[$cat_key]:-}" ]]; then
            seen_cats[$cat_key]=1
            categories+=("${(C)cat}")
        fi
    done
    local cat_name
    for cat_name in "${categories[@]}"; do
        local cat_lower="${cat_name:l}"
        local cat_pass=0
        local cat_warn=0
        local cat_fail=0
        local cat_earned=0.0
        local cat_total=0.0

        for (( j = 1; j <= n; j++ )); do
            local c="${RES_CATEGORIES[j]:l}"
            if [[ "$c" == "$cat_lower" ]]; then
                local st="${RES_STATUSES[j]}"
                local w="${RES_WEIGHTS[j]:-5}"
                [[ "$w" =~ ^[0-9]+(\.[0-9]+)?$ ]] || w=5.0

                case "$st" in
                    PASS)
                        (( ++cat_pass ))
                        cat_total=$(( cat_total + w ))
                        cat_earned=$(( cat_earned + w ))
                        ;;
                    WARN)
                        (( ++cat_warn ))
                        cat_total=$(( cat_total + w ))
                        cat_earned=$(( cat_earned + (w * 0.5) ))
                        ;;
                    FAIL)
                        (( ++cat_fail ))
                        cat_total=$(( cat_total + w ))
                        ;;
                    *)
                        ;;
                esac
            fi
        done

        local cat_score_pct=100.0
        if (( cat_total > 0.0 )); then
            cat_score_pct=$(( (cat_earned / cat_total) * 100.0 ))
        elif (( cat_pass + cat_warn + cat_fail == 0 )); then
            cat_score_pct=0.0
        fi
        local cat_score_fmt=$(printf "%.1f" "$cat_score_pct")

        local int_cscore=0
        if [[ "$cat_score_fmt" =~ ^[0-9]+ ]]; then
            int_cscore=${cat_score_fmt%%.*}
        fi

        local indicator="🟩"
        local status_lbl="🟢 PASS"
        local fill_sym="🟩"
        if (( int_cscore >= 85 )); then
            indicator="🟩"
            if (( is_tr )); then
                status_lbl="🟢 $(i18n_t "ui.status.pass" "BAŞARILI")"
            else
                status_lbl="🟢 PASS"
            fi
            fill_sym="🟩"
        elif (( int_cscore >= 70 )); then
            indicator="🟨"
            if (( is_tr )); then
                status_lbl="🟡 $(i18n_t "ui.status.warn" "UYARI")"
            else
                status_lbl="🟡 WARN"
            fi
            fill_sym="🟨"
        else
            indicator="🟥"
            if (( is_tr )); then
                status_lbl="🔴 $(i18n_t "ui.status.deficient" "YETERSİZ")"
            else
                status_lbl="🔴 DEFICIENT"
            fi
            fill_sym="🟥"
        fi

        local fill_cnt=$(( (int_cscore * 10) / 100 ))
        local empty_cnt=$(( 10 - fill_cnt ))
        (( fill_cnt < 0 )) && fill_cnt=0
        (( empty_cnt < 0 )) && empty_cnt=0

        local bar=""
        for (( b = 0; b < fill_cnt; b++ )); do bar+="$fill_sym"; done
        for (( b = 0; b < empty_cnt; b++ )); do bar+="⬜"; done

        local earned_fmt=$(printf "%.1f" "$cat_earned")
        local total_fmt=$(printf "%.1f" "$cat_total")

        local display_cat_name="$cat_name"
        if (( is_tr )); then
            display_cat_name="$(i18n_get_category_name "$cat_lower")"
        fi

        cat_table+="| **${display_cat_name}** | **${cat_score_fmt}%** | ${indicator} ${bar} | ${status_lbl} | ${cat_pass} | ${cat_warn} | ${cat_fail} | ${earned_fmt} / ${total_fmt} |
"
    done

    # Build Risk & Severity Distribution markdown table
    local crit_total=0; local crit_pass=0; local crit_warn=0; local crit_fail=0; local crit_earned=0.0; local crit_pts=0.0
    local high_total=0; local high_pass=0; local high_warn=0; local high_fail=0; local high_earned=0.0; local high_pts=0.0
    local med_total=0;  local med_pass=0;  local med_warn=0;  local med_fail=0;  local med_earned=0.0;  local med_pts=0.0
    local low_total=0;  local low_pass=0;  local low_warn=0;  local low_fail=0;  local low_earned=0.0;  local low_pts=0.0

    for (( j = 1; j <= n; j++ )); do
        local st="${RES_STATUSES[j]}"
        local w="${RES_WEIGHTS[j]:-5}"
        [[ "$w" =~ ^[0-9]+(\.[0-9]+)?$ ]] || w=5.0
        local int_w=5
        if [[ "$w" =~ ^[0-9]+ ]]; then
            int_w=${w%%.*}
        fi

        local is_scored=1
        if [[ "$st" == "INFO" || "$st" == "SUGG" ]]; then
            is_scored=0
        fi

        if (( int_w >= 9 )); then
            (( ++crit_total ))
            if [[ "$st" == "PASS" ]]; then (( ++crit_pass )); crit_earned=$(( crit_earned + w )); fi
            if [[ "$st" == "WARN" ]]; then (( ++crit_warn )); crit_earned=$(( crit_earned + (w * 0.5) )); fi
            if [[ "$st" == "FAIL" ]]; then (( ++crit_fail )); fi
            (( is_scored )) && crit_pts=$(( crit_pts + w ))
        elif (( int_w >= 7 )); then
            (( ++high_total ))
            if [[ "$st" == "PASS" ]]; then (( ++high_pass )); high_earned=$(( high_earned + w )); fi
            if [[ "$st" == "WARN" ]]; then (( ++high_warn )); high_earned=$(( high_earned + (w * 0.5) )); fi
            if [[ "$st" == "FAIL" ]]; then (( ++high_fail )); fi
            (( is_scored )) && high_pts=$(( high_pts + w ))
        elif (( int_w >= 5 )); then
            (( ++med_total ))
            if [[ "$st" == "PASS" ]]; then (( ++med_pass )); med_earned=$(( med_earned + w )); fi
            if [[ "$st" == "WARN" ]]; then (( ++med_warn )); med_earned=$(( med_earned + (w * 0.5) )); fi
            if [[ "$st" == "FAIL" ]]; then (( ++med_fail )); fi
            (( is_scored )) && med_pts=$(( med_pts + w ))
        else
            (( ++low_total ))
            if [[ "$st" == "PASS" ]]; then (( ++low_pass )); low_earned=$(( low_earned + w )); fi
            if [[ "$st" == "WARN" ]]; then (( ++low_warn )); low_earned=$(( low_earned + (w * 0.5) )); fi
            if [[ "$st" == "FAIL" ]]; then (( ++low_fail )); fi
            (( is_scored )) && low_pts=$(( low_pts + w ))
        fi
    done

    local crit_rate="100.0%"
    (( crit_pts > 0.0 )) && crit_rate=$(printf "%.1f%%" $(( (crit_earned / crit_pts) * 100.0 )))
    local high_rate="100.0%"
    (( high_pts > 0.0 )) && high_rate=$(printf "%.1f%%" $(( (high_earned / high_pts) * 100.0 )))
    local med_rate="100.0%"
    (( med_pts > 0.0 )) && med_rate=$(printf "%.1f%%" $(( (med_earned / med_pts) * 100.0 )))
    local low_rate="100.0%"
    (( low_pts > 0.0 )) && low_rate=$(printf "%.1f%%" $(( (low_earned / low_pts) * 100.0 )))

    local sev_table=""
    if (( is_tr )); then
        sev_table+="| $(i18n_t "ui.table_headers.severity_level" "Önem Derecesi") | $(i18n_t "ui.table_headers.weight_range" "Ağırlık Aralığı") | $(i18n_t "ui.table_headers.total_checks" "Toplam Kontrol") | $(i18n_t "ui.table_headers.passed" "Başarılı") | $(i18n_t "ui.table_headers.warnings" "Uyarılar") | $(i18n_t "ui.table_headers.failed" "Başarısız") | $(i18n_t "ui.table_headers.compliance_rate" "Uyumluluk Oranı") |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| 🔴 **$(i18n_t "ui.status.critical" "Kritik")** | $(i18n_t "ui.table_headers.weight" "Ağırlık") 9 – 10 | ${crit_total} | ${crit_pass} | ${crit_warn} | ${crit_fail} | ${crit_rate} |
| 🟠 **$(i18n_t "ui.status.high" "Yüksek")** | $(i18n_t "ui.table_headers.weight" "Ağırlık") 7 – 8 | ${high_total} | ${high_pass} | ${high_warn} | ${high_fail} | ${high_rate} |
| 🟡 **$(i18n_t "ui.status.medium" "Orta")** | $(i18n_t "ui.table_headers.weight" "Ağırlık") 5 – 6 | ${med_total} | ${med_pass} | ${med_warn} | ${med_fail} | ${med_rate} |
| 🔵 **$(i18n_t "ui.status.low" "Düşük")** | $(i18n_t "ui.table_headers.weight" "Ağırlık") 1 – 4 | ${low_total} | ${low_pass} | ${low_warn} | ${low_fail} | ${low_rate} |
"
    else
        sev_table+="| Severity Level | Weight Range | Total Checks | Passed | Warnings | Failed | Compliance Rate |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| 🔴 **Critical** | Weight 9 – 10 | ${crit_total} | ${crit_pass} | ${crit_warn} | ${crit_fail} | ${crit_rate} |
| 🟠 **High** | Weight 7 – 8 | ${high_total} | ${high_pass} | ${high_warn} | ${high_fail} | ${high_rate} |
| 🟡 **Medium** | Weight 5 – 6 | ${med_total} | ${med_pass} | ${med_warn} | ${med_fail} | ${med_rate} |
| 🔵 **Low** | Weight 1 – 4 | ${low_total} | ${low_pass} | ${low_warn} | ${low_fail} | ${low_rate} |
"
    fi

    # Ensure compliance metrics are loaded
    if ! typeset -f calculate_compliance_metrics >/dev/null 2>&1; then
        if [[ -f "${0:A:h}/compliance.sh" ]]; then
            source "${0:A:h}/compliance.sh"
        elif [[ -n "${LIB_DIR:-}" && -f "${LIB_DIR}/compliance.sh" ]]; then
            source "${LIB_DIR}/compliance.sh"
        elif [[ -f "./lib/compliance.sh" ]]; then
            source "./lib/compliance.sh"
        elif [[ -f "../lib/compliance.sh" ]]; then
            source "../lib/compliance.sh"
        fi
    fi

    if typeset -f calculate_compliance_metrics >/dev/null 2>&1; then
        calculate_compliance_metrics
    fi

    local cis_rating="N/A"
    local nist_rating="N/A"
    local mitre_rating="N/A"
    if typeset -f _compliance_rating_text >/dev/null 2>&1; then
        cis_rating=$(_compliance_rating_text "${CIS_COMPLIANCE_PCT:-100.0}")
        nist_rating=$(_compliance_rating_text "${NIST_COMPLIANCE_PCT:-100.0}")
        mitre_rating=$(_compliance_rating_text "${MITRE_COVERAGE_PCT:-100.0}")
    else
        cis_rating=$(_get_rating_text "${CIS_COMPLIANCE_PCT:-100.0}")
        nist_rating=$(_get_rating_text "${NIST_COMPLIANCE_PCT:-100.0}")
        mitre_rating=$(_get_rating_text "${MITRE_COVERAGE_PCT:-100.0}")
    fi

    local reg_table=""
    if (( is_tr )); then
        reg_table+="| $(i18n_t "ui.table_headers.framework" "Çerçeve") | $(i18n_t "ui.table_headers.compliance_score" "Uyumluluk Skoru") | $(i18n_t "ui.table_headers.status" "Durum") | $(i18n_t "ui.table_headers.evaluated" "Değerlendirilen") | $(i18n_t "ui.table_headers.compliant_defended" "Uyumlu / Savunulan") | $(i18n_t "ui.table_headers.warnings" "Uyarılar") | $(i18n_t "ui.table_headers.deficiencies" "Eksiklikler") |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **CIS Apple macOS Benchmark** | **${CIS_COMPLIANCE_PCT:-100.0}%** | ${cis_rating} | ${CIS_TOTAL_COUNT:-0} | ${CIS_PASS_COUNT:-0} | ${CIS_WARN_COUNT:-0} | ${CIS_FAIL_COUNT:-0} |
| **NIST SP 800-53 Rev. 5** | **${NIST_COMPLIANCE_PCT:-100.0}%** | ${nist_rating} | ${NIST_TOTAL_COUNT:-0} | ${NIST_PASS_COUNT:-0} | ${NIST_WARN_COUNT:-0} | ${NIST_FAIL_COUNT:-0} |
| **MITRE ATT&CK (macOS Defense)** | **${MITRE_COVERAGE_PCT:-100.0}%** | ${mitre_rating} | ${MITRE_TOTAL_COUNT:-0} | ${MITRE_DEFENDED_COUNT:-0} | - | ${MITRE_AT_RISK_COUNT:-0} |
"
    else
        reg_table+="| Framework | Compliance Score | Status | Evaluated | Compliant / Defended | Warnings | Deficiencies |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **CIS Apple macOS Benchmark** | **${CIS_COMPLIANCE_PCT:-100.0}%** | ${cis_rating} | ${CIS_TOTAL_COUNT:-0} | ${CIS_PASS_COUNT:-0} | ${CIS_WARN_COUNT:-0} | ${CIS_FAIL_COUNT:-0} |
| **NIST SP 800-53 Rev. 5** | **${NIST_COMPLIANCE_PCT:-100.0}%** | ${nist_rating} | ${NIST_TOTAL_COUNT:-0} | ${NIST_PASS_COUNT:-0} | ${NIST_WARN_COUNT:-0} | ${NIST_FAIL_COUNT:-0} |
| **MITRE ATT&CK (macOS Defense)** | **${MITRE_COVERAGE_PCT:-100.0}%** | ${mitre_rating} | ${MITRE_TOTAL_COUNT:-0} | ${MITRE_DEFENDED_COUNT:-0} | - | ${MITRE_AT_RISK_COUNT:-0} |
"
    fi

    local md_content=""
    if (( is_tr )); then
        md_content="# macOS Güvenlik Sıkılaştırma Denetim Raporu

> **Otomatik Güvenlik ve Uyumluluk Taraması**  
> **macharden** v${version} tarafından \`${current_time}\` tarihinde oluşturuldu

---

## 1. $(i18n_t "ui.sections.system_metadata" "Sistem Meta Verileri")

| $(i18n_t "ui.table_headers.attribute" "Öznitelik") | $(i18n_t "ui.table_headers.system_info" "Sistem Bilgisi") |
| :--- | :--- |
| **$(i18n_t "ui.kpi.target_host" "Hedef Sistem Adı")** | \`${hostname}\` |
| **Denetim Kullanıcısı** | \`${current_user}\` |
| **İşletim Sistemi** | ${os_product} ${os_version} (Build \`${os_build}\`) |
| **Mimari** | \`${arch}\` |
| **Çekirdek Sürümü** | \`${kernel_rel}\` |

---

## 2. $(i18n_t "ui.sections.executive_summary" "Yönetici Özeti")

### $(i18n_t "ui.hardening_index" "Sıkılaştırma İndeksi"): **${HARDENING_INDEX}%** — *${rating}* ($(i18n_t "ui.grade" "Derece"): **${letter_grade}**)

| $(i18n_t "ui.table_headers.metric" "Metrik") | $(i18n_t "ui.table_headers.count_value" "Sayı / Değer") | $(i18n_t "ui.table_headers.status" "Durum") |
| :--- | :---: | :---: |
| **$(i18n_t "ui.hardening_score" "Sıkılaştırma Skoru")** | **${HARDENING_INDEX}%** | **${rating}** ($(i18n_t "ui.grade" "Derece"): **${letter_grade}**) |
| **$(i18n_t "ui.total_checks_audited" "Denetlenen Toplam Kontrol")** | **${COUNT_TOTAL}** | - |
| **$(i18n_t "ui.passed_checks" "Başarılı Kontroller")** | **${COUNT_PASS}** | 🟢 $(i18n_t "ui.status.pass" "BAŞARILI") |
| **$(i18n_t "ui.warnings" "Uyarılar")** | **${COUNT_WARN}** | 🟡 $(i18n_t "ui.status.warn" "UYARI") |
| **$(i18n_t "ui.failed_checks" "Başarısız Kontroller")** | **${COUNT_FAIL}** | 🔴 $(i18n_t "ui.status.fail" "BAŞARISIZ") |
| **$(i18n_t "ui.informational" "Bilgilendirme")** | **${COUNT_INFO}** | 🔵 $(i18n_t "ui.status.info" "BİLGİ") |
| **$(i18n_t "ui.suggestions" "Öneriler")** | **${COUNT_SUGG}** | 🟣 $(i18n_t "ui.status.sugg" "ÖNERİ") |
| **$(i18n_t "ui.score_points_earned" "Kazanılan Skor Puanı")** | **${points_display}** | - |

---

### $(i18n_t "ui.sections.category_posture_breakdown" "Kategori Bazlı Güvenlik Durumu")

${cat_table}
---

### $(i18n_t "ui.sections.risk_severity_distribution" "Risk ve Önem Derecesi Dağılımı")

${sev_table}
---

### $(i18n_t "ui.sections.regulatory_framework_coverage" "Mevzuat ve Uyumluluk Çerçevesi Kapsamı")

${reg_table}
---

## 3. $(i18n_t "ui.sections.comprehensive_audit_results" "Kapsamlı Denetim Sonuçları")

| $(i18n_t "ui.table_headers.status" "Durum") | $(i18n_t "ui.table_headers.id" "Kimlik") | $(i18n_t "ui.table_headers.category" "Kategori") | $(i18n_t "ui.table_headers.title" "Kontrol Başlığı") | $(i18n_t "ui.table_headers.weight" "Ağırlık") | $(i18n_t "ui.table_headers.details" "Ayrıntılar") |
| :---: | :--- | :--- | :--- | :---: | :--- |
"
    else
        md_content="# macOS Security Hardening Audit Report

> **Automated Security & Compliance Scan**  
> Generated by **macharden** v${version} on \`${current_time}\`

---

## 1. System Metadata

| Attribute | System Information |
| :--- | :--- |
| **Target Hostname** | \`${hostname}\` |
| **Audit User** | \`${current_user}\` |
| **Operating System** | ${os_product} ${os_version} (Build \`${os_build}\`) |
| **Architecture** | \`${arch}\` |
| **Kernel Release** | \`${kernel_rel}\` |

---

## 2. Executive Summary

### Hardening Index: **${HARDENING_INDEX}%** — *${rating}* (Grade: **${letter_grade}**)

| Metric | Count / Value | Status |
| :--- | :---: | :---: |
| **Hardening Score** | **${HARDENING_INDEX}%** | **${rating}** (Grade: **${letter_grade}**) |
| **Total Checks Audited** | **${COUNT_TOTAL}** | - |
| **Passed Checks** | **${COUNT_PASS}** | 🟢 PASS |
| **Warnings** | **${COUNT_WARN}** | 🟡 WARN |
| **Failed Checks** | **${COUNT_FAIL}** | 🔴 FAIL |
| **Informational** | **${COUNT_INFO}** | 🔵 INFO |
| **Suggestions** | **${COUNT_SUGG}** | 🟣 SUGG |
| **Earned Score Points** | **${points_display}** | - |

---

### Category Posture Breakdown

${cat_table}
---

### Risk & Severity Distribution

${sev_table}
---

### Regulatory Framework Coverage

${reg_table}
---

## 3. Comprehensive Audit Results

| Status | ID | Category | Check Title | Weight | Details |
| :---: | :--- | :--- | :--- | :---: | :--- |
"
    fi

    local n=${#RES_IDS[@]}
    for (( i = 1; i <= n; i++ )); do
        local id="${RES_IDS[i]}"
        local cat="${RES_CATEGORIES[i]}"
        local title="${RES_TITLES[i]}"
        local st="${RES_STATUSES[i]}"
        local weight="${RES_WEIGHTS[i]}"
        local details="${RES_DETAILS[i]}"
        
        # Clean details for markdown table (replace pipes and newlines)
        details="${details//|/\\|}"
        details="${details//$'\n'/<br>}"

        local status_badge=""
        if (( is_tr )); then
            case "$st" in
                PASS) status_badge="🟢 $(i18n_t "ui.status.pass" "BAŞARILI")" ;;
                WARN) status_badge="🟡 $(i18n_t "ui.status.warn" "UYARI")" ;;
                FAIL) status_badge="🔴 $(i18n_t "ui.status.fail" "BAŞARISIZ")" ;;
                INFO) status_badge="🔵 $(i18n_t "ui.status.info" "BİLGİ")" ;;
                SUGG) status_badge="🟣 $(i18n_t "ui.status.sugg" "ÖNERİ")" ;;
                *)    status_badge="⚪ $st" ;;
            esac
            title=$(i18n_get_check_title "$id" "$title")
            details=$(i18n_get_check_details "$id" "$st" "$details")
            cat=$(i18n_get_category_name "$cat")
        else
            case "$st" in
                PASS) status_badge="🟢 PASS" ;;
                WARN) status_badge="🟡 WARN" ;;
                FAIL) status_badge="🔴 FAIL" ;;
                INFO) status_badge="🔵 INFO" ;;
                SUGG) status_badge="🟣 SUGG" ;;
                *)    status_badge="⚪ $st" ;;
            esac
        fi

        md_content+="${status_badge} | \`${id}\` | \`${cat}\` | ${title} | ${weight} | ${details:-N/A}
"
    done

    if (( is_tr )); then
        md_content+="
---

## 4. $(i18n_t "ui.sections.remediation_playbook" "İyileştirme Kılavuzu")

"
    else
        md_content+="
---

## 4. Remediation Playbook

"
    fi

    local has_remediation=0
    for (( i = 1; i <= n; i++ )); do
        local st="${RES_STATUSES[i]}"
        local rem="${RES_REMEDIATIONS[i]}"
        if [[ ( "$st" == "FAIL" || "$st" == "WARN" ) && -n "$rem" ]]; then
            has_remediation=1
            local id="${RES_IDS[i]}"
            local cat="${RES_CATEGORIES[i]}"
            local title="${RES_TITLES[i]}"
            local weight="${RES_WEIGHTS[i]}"
            local details="${RES_DETAILS[i]}"

            local icon="🔴"
            [[ "$st" == "WARN" ]] && icon="🟡"

            local ref_md=""
            if typeset -f get_compliance_references >/dev/null 2>&1; then
                ref_md=$(get_compliance_references "$id" "markdown" 2>/dev/null || true)
            fi

            if (( is_tr )); then
                title=$(i18n_get_check_title "$id" "$title")
                details=$(i18n_get_check_details "$id" "$st" "$details")
                cat=$(i18n_get_category_name "$cat")
                local st_label="$st"
                case "$st" in
                    FAIL) st_label="$(i18n_t "ui.status.fail" "BAŞARISIZ")" ;;
                    WARN) st_label="$(i18n_t "ui.status.warn" "UYARI")" ;;
                esac

                md_content+="### ${icon} [\`${id}\`] ${title}

- **Kategori:** \`${cat}\`
- **Önem Derecesi / Ağırlık:** ${weight}
- **Durum:** **${st_label}**
- **Bulgu:** ${details}
- **İyileştirme Komutu:**
\`\`\`bash
${rem}
\`\`\`
"
                if [[ -n "$ref_md" ]]; then
                    md_content+="- **Yetkili Referanslar:**
${ref_md}
"
                fi
                md_content+="
"
            else
                md_content+="### ${icon} [\`${id}\`] ${title}

- **Category:** \`${cat}\`
- **Severity / Weight:** ${weight}
- **Status:** **${st}**
- **Finding:** ${details}
- **Remediation Command:**
\`\`\`bash
${rem}
\`\`\`
"
                if [[ -n "$ref_md" ]]; then
                    md_content+="- **Authoritative References:**
${ref_md}
"
                fi
                md_content+="
"
            fi
        fi
    done

    if (( ! has_remediation )); then
        if (( is_tr )); then
            md_content+="*$(i18n_t "ui.remediation.no_critical_remediation" "Kritik iyileştirme komutu gerekmiyor. Denetlenen tüm güvenlik kontrolleri gereksinimleri karşılıyor.")*
"
        else
            md_content+="*No critical remediation commands required. All audited security controls meet requirements.*
"
        fi
    fi

    if (( is_tr )); then
        md_content+="
---
*Rapor [macharden](https://github.com/macharden/macharden) tarafından otomatik olarak oluşturulmuştur.*
"
    else
        md_content+="
---
*Report generated automatically by [macharden](https://github.com/macharden/macharden).*
"
    fi

    if [[ -n "$output_file" && "$output_file" != "-" ]]; then
        local out_dir="${output_file:h}"
        [[ -d "$out_dir" ]] || mkdir -p "$out_dir"
        printf "%s\n" "$md_content" > "$output_file"
        if [[ "${MACHAR_QUIET:-0}" -eq 0 ]]; then
            ui_success "Markdown report generated: ${output_file}"
        fi
    else
        printf "%s\n" "$md_content"
    fi
}

# Generate structured JSON document
report_json() {
    local output_file="${1:-}"
    local version="${MACHAR_VERSION:-1.3.0}"
    local os_product os_version os_build arch current_time current_user hostname kernel_rel rating

    os_product=$(sw_vers -productName 2>/dev/null || echo "macOS")
    os_version=$(sw_vers -productVersion 2>/dev/null || echo "Unknown")
    os_build=$(sw_vers -buildVersion 2>/dev/null || echo "Unknown")
    arch=$(uname -m 2>/dev/null || echo "arm64")
    kernel_rel=$(uname -r 2>/dev/null || echo "Darwin")
    current_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    current_user=$(id -un 2>/dev/null || whoami)
    hostname=$(hostname -s 2>/dev/null || hostname)
    rating=$(_get_rating_text "$HARDENING_INDEX")

    local diff_payload=""
    if [[ -n "${BASELINE_FILE:-}" ]] && typeset -f diff_get_json >/dev/null 2>&1; then
        diff_payload=$(diff_get_json)
    fi

    # Build checks array via python3 if available for 100% strict JSON conformity
    if command -v python3 >/dev/null 2>&1; then
        local n=${#RES_IDS[@]}
        local json_doc
        json_doc=$(python3 -c "
import sys, json, os

n = int(sys.argv[1])
idx = 2

ids = sys.argv[idx : idx + n]; idx += n
cats = sys.argv[idx : idx + n]; idx += n
titles = sys.argv[idx : idx + n]; idx += n
statuses = sys.argv[idx : idx + n]; idx += n
weights = sys.argv[idx : idx + n]; idx += n
details = sys.argv[idx : idx + n]; idx += n
remediations = sys.argv[idx : idx + n]; idx += n

comp_map = {}
for p in ['data/compliance_mappings.json', '../data/compliance_mappings.json', os.environ.get('BASE_DIR', '') + '/data/compliance_mappings.json']:
    if os.path.isfile(p):
        try:
            with open(p, 'r', encoding='utf-8') as f:
                comp_map = json.load(f).get('mappings', {})
                if comp_map:
                    break
        except Exception:
            pass

checks = []
for i in range(n):
    try:
        w = float(weights[i]) if '.' in weights[i] else int(weights[i])
    except ValueError:
        w = 5
    cid = ids[i]
    refs = comp_map.get(cid, {}).get('references', [])
    checks.append({
        'id': cid,
        'category': cats[i],
        'title': titles[i],
        'status': statuses[i],
        'weight': w,
        'details': details[i],
        'remediation': remediations[i],
        'references': refs
    })

data = {
    'scanner': {
        'name': 'macharden',
        'version': sys.argv[idx],
        'timestamp': sys.argv[idx + 1]
    },
    'system': {
        'hostname': sys.argv[idx + 2],
        'user': sys.argv[idx + 3],
        'os_product': sys.argv[idx + 4],
        'os_version': sys.argv[idx + 5],
        'os_build': sys.argv[idx + 6],
        'arch': sys.argv[idx + 7],
        'kernel': sys.argv[idx + 8]
    },
    'summary': {
        'hardening_index': float(sys.argv[idx + 9]),
        'rating': sys.argv[idx + 10],
        'total_checks': int(sys.argv[idx + 11]),
        'passed': int(sys.argv[idx + 12]),
        'warnings': int(sys.argv[idx + 13]),
        'failed': int(sys.argv[idx + 14]),
        'info': int(sys.argv[idx + 15]),
        'suggestions': int(sys.argv[idx + 16]),
        'earned_points': float(sys.argv[idx + 17]),
        'total_possible_points': float(sys.argv[idx + 18])
    },
    'checks': checks
}

if len(sys.argv) > idx + 19 and sys.argv[idx + 19]:
    try:
        data['diff'] = json.loads(sys.argv[idx + 19])
    except Exception:
        pass

print(json.dumps(data, indent=2))
" \
            "$n" \
            "${RES_IDS[@]}" \
            "${RES_CATEGORIES[@]}" \
            "${RES_TITLES[@]}" \
            "${RES_STATUSES[@]}" \
            "${RES_WEIGHTS[@]}" \
            "${RES_DETAILS[@]}" \
            "${RES_REMEDIATIONS[@]}" \
            "$version" \
            "$current_time" \
            "$hostname" \
            "$current_user" \
            "$os_product" \
            "$os_version" \
            "$os_build" \
            "$arch" \
            "$kernel_rel" \
            "$HARDENING_INDEX" \
            "$rating" \
            "$COUNT_TOTAL" \
            "$COUNT_PASS" \
            "$COUNT_WARN" \
            "$COUNT_FAIL" \
            "$COUNT_INFO" \
            "$COUNT_SUGG" \
            "$EARNED_POINTS" \
            "$TOTAL_POSSIBLE_POINTS" \
            "$diff_payload"
        )
    else
        # Pure shell fallback
        local json_doc="{\n"
        json_doc+="  \"scanner\": {\n"
        json_doc+="    \"name\": \"macharden\",\n"
        json_doc+="    \"version\": \"${version}\",\n"
        json_doc+="    \"timestamp\": \"${current_time}\"\n"
        json_doc+="  },\n"
        json_doc+="  \"system\": {\n"
        json_doc+="    \"hostname\": \"${hostname}\",\n"
        json_doc+="    \"user\": \"${current_user}\",\n"
        json_doc+="    \"os_product\": \"${os_product}\",\n"
        json_doc+="    \"os_version\": \"${os_version}\",\n"
        json_doc+="    \"os_build\": \"${os_build}\",\n"
        json_doc+="    \"arch\": \"${arch}\",\n"
        json_doc+="    \"kernel\": \"${kernel_rel}\"\n"
        json_doc+="  },\n"
        json_doc+="  \"summary\": {\n"
        json_doc+="    \"hardening_index\": ${HARDENING_INDEX},\n"
        json_doc+="    \"rating\": \"${rating}\",\n"
        json_doc+="    \"total_checks\": ${COUNT_TOTAL},\n"
        json_doc+="    \"passed\": ${COUNT_PASS},\n"
        json_doc+="    \"warnings\": ${COUNT_WARN},\n"
        json_doc+="    \"failed\": ${COUNT_FAIL},\n"
        json_doc+="    \"info\": ${COUNT_INFO},\n"
        json_doc+="    \"suggestions\": ${COUNT_SUGG},\n"
        json_doc+="    \"earned_points\": ${EARNED_POINTS},\n"
        json_doc+="    \"total_possible_points\": ${TOTAL_POSSIBLE_POINTS}\n"
        json_doc+="  },\n"
        json_doc+="  \"checks\": [\n"

        local n=${#RES_IDS[@]}
        for (( i = 1; i <= n; i++ )); do
            local d="${RES_DETAILS[i]}"
            local r="${RES_REMEDIATIONS[i]}"
            d="${d//\\/\\\\}"; d="${d//\"/\\\"}"; d="${d//$'\n'/\\n}"
            r="${r//\\/\\\\}"; r="${r//\"/\\\"}"; r="${r//$'\n'/\\n}"

            json_doc+="    {\n"
            json_doc+="      \"id\": \"${RES_IDS[i]}\",\n"
            json_doc+="      \"category\": \"${RES_CATEGORIES[i]}\",\n"
            json_doc+="      \"title\": \"${RES_TITLES[i]}\",\n"
            json_doc+="      \"status\": \"${RES_STATUSES[i]}\",\n"
            json_doc+="      \"weight\": ${RES_WEIGHTS[i]:-5},\n"
            json_doc+="      \"details\": \"${d}\",\n"
            json_doc+="      \"remediation\": \"${r}\",\n"
            json_doc+="      \"references\": []\n"
            if (( i < n )); then
                json_doc+="    },\n"
            else
                json_doc+="    }\n"
            fi
        done
        json_doc+="  ]\n"
        json_doc+="}\n"
    fi

    if [[ -n "$output_file" && "$output_file" != "-" ]]; then
        local out_dir="${output_file:h}"
        [[ -d "$out_dir" ]] || mkdir -p "$out_dir"
        printf "%s\n" "$json_doc" > "$output_file"
        if [[ "${MACHAR_QUIET:-0}" -eq 0 ]]; then
            ui_success "JSON report generated: ${output_file}"
        fi
    else
        printf "%s\n" "$json_doc"
    fi
}

# Source HTML report engine if available
if [[ -f "${0:A:h}/report_html.sh" ]]; then
    source "${0:A:h}/report_html.sh"
fi

# Source diff engine if available
if [[ -f "${0:A:h}/diff.sh" ]]; then
    source "${0:A:h}/diff.sh"
fi

# Source SARIF report engine if available
if [[ -f "${0:A:h}/report_sarif.sh" ]]; then
    source "${0:A:h}/report_sarif.sh"
fi
