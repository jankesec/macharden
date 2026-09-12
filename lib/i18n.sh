#!/bin/zsh
# ==============================================================================
# macharden - lib/i18n.sh
# Internationalization (i18n) and localization framework
# ==============================================================================

# Global localization state
typeset -g CURRENT_LANG="en"
typeset -gA I18N_CACHE=()
typeset -gA I18N_CHECK_TITLES=()
typeset -gA I18N_CHECK_PASS=()
typeset -gA I18N_CHECK_WARN=()
typeset -gA I18N_CHECK_FAIL=()
typeset -gA I18N_CHECK_REM=()
typeset -gi I18N_LOADED=0

# Locate locale JSON file on disk
_i18n_find_locale_file() {
    local lang="$1"
    if [[ -n "${BASE_DIR:-}" && -f "${BASE_DIR}/data/locales/${lang}.json" ]]; then
        echo "${BASE_DIR}/data/locales/${lang}.json"
        return 0
    fi
    if [[ -f "./data/locales/${lang}.json" ]]; then
        echo "./data/locales/${lang}.json"
        return 0
    fi
    if [[ -f "../data/locales/${lang}.json" ]]; then
        echo "../data/locales/${lang}.json"
        return 0
    fi
    local self_dir="${0:A:h}"
    if [[ -f "${self_dir}/../data/locales/${lang}.json" ]]; then
        echo "${self_dir}/../data/locales/${lang}.json"
        return 0
    fi
    if [[ -f "${BASE_DIR}/data/locales/${lang}.json" ]]; then
        echo "${BASE_DIR}/data/locales/${lang}.json"
        return 0
    fi
    return 1
}

# Parse and cache locale data from JSON
_i18n_load_locale() {
    local lang="${1:-tr}"
    local json_file
    json_file=$(_i18n_find_locale_file "$lang") || return 1
    [[ -f "$json_file" ]] || return 1

    if ! command -v python3 >/dev/null 2>&1; then
        return 1
    fi

    local tsv_data
    tsv_data=$(python3 -c '
import json, sys

try:
    with open(sys.argv[1], encoding="utf-8") as f:
        data = json.load(f)

    def flatten(d, prefix=""):
        for k, v in d.items():
            full = f"{prefix}.{k}" if prefix else k
            if isinstance(v, dict):
                flatten(v, full)
                if prefix == "ui":
                    flatten(v, k)
            elif isinstance(v, str):
                clean_v = v.replace("\\", "\\\\").replace("\t", " ").replace("\n", "\\n")
                print(f"UI\t{full}\t{clean_v}")
                if prefix == "ui":
                    print(f"UI\t{k}\t{clean_v}")

    flatten(data.get("ui", {}), "ui")

    for cid, cdata in data.get("checks", {}).items():
        cid_up = cid.upper()
        for field in ["title", "details_pass", "details_warn", "details_fail", "remediation_desc"]:
            val = cdata.get(field, "")
            clean_v = val.replace("\\", "\\\\").replace("\t", " ").replace("\n", "\\n")
            print(f"CHECK\t{cid_up}\t{field}\t{clean_v}")
except Exception:
    pass
' "$json_file" 2>/dev/null)

    local line_type="" k1="" k2="" k3=""
    while IFS=$'\t' read -r line_type k1 k2 k3; do
        if [[ "$line_type" == "UI" ]]; then
            I18N_CACHE[$k1]="$k2"
        elif [[ "$line_type" == "CHECK" ]]; then
            case "$k2" in
                title)
                    I18N_CHECK_TITLES[$k1]="$k3"
                    ;;
                details_pass)
                    I18N_CHECK_PASS[$k1]="$k3"
                    ;;
                details_warn)
                    I18N_CHECK_WARN[$k1]="$k3"
                    ;;
                details_fail)
                    I18N_CHECK_FAIL[$k1]="$k3"
                    ;;
                remediation_desc)
                    I18N_CHECK_REM[$k1]="$k3"
                    ;;
            esac
        fi
    done <<< "$tsv_data"

    I18N_LOADED=1
    return 0
}

# Initialize localization language
# Usage: i18n_init [lang]
i18n_init() {
    local requested="${1:-}"
    if [[ -z "$requested" ]]; then
        requested="${MACHAR_LANG:-}"
    fi
    if [[ -z "$requested" ]]; then
        requested="${LANG:-}"
    fi

    # Normalize language string (defaults to 'en')
    local lower_req="${requested:l}"
    if [[ "$lower_req" == tr* ]]; then
        CURRENT_LANG="tr"
    else
        CURRENT_LANG="en"
    fi
    export CURRENT_LANG

    # If Turkish selected, preload translations
    if [[ "$CURRENT_LANG" == "tr" ]]; then
        _i18n_load_locale "tr"
    fi
}

# Translate UI string
# Usage: i18n_t <key> [default_value]
i18n_t() {
    local key="$1"
    local default_val="${2:-$1}"

    if [[ "${CURRENT_LANG:-en}" != "tr" ]]; then
        echo "$default_val"
        return 0
    fi

    if (( ! I18N_LOADED )); then
        _i18n_load_locale "tr"
    fi

    local val="${I18N_CACHE[$key]:-}"
    if [[ -n "$val" ]]; then
        echo "$val"
    else
        echo "$default_val"
    fi
}

# Get translated check title
# Usage: i18n_get_check_title <check_id> [default_title]
i18n_get_check_title() {
    local check_id="${1:-}"
    local default_title="${2:-$check_id}"
    local cid_up="${check_id:u}"

    if [[ "${CURRENT_LANG:-en}" != "tr" ]]; then
        echo "$default_title"
        return 0
    fi

    if (( ! I18N_LOADED )); then
        _i18n_load_locale "tr"
    fi

    local title="${I18N_CHECK_TITLES[$cid_up]:-}"
    if [[ -n "$title" ]]; then
        echo "$title"
    else
        echo "$default_title"
    fi
}

# Get translated check details by finding outcome
# Usage: i18n_get_check_details <check_id> <status> [default_details]
i18n_get_check_details() {
    local check_id="${1:-}"
    local check_status="${2:-}"
    local default_details="${3:-}"
    local cid_up="${check_id:u}"
    local st_up="${check_status:u}"

    if [[ "${CURRENT_LANG:-en}" != "tr" ]]; then
        echo "$default_details"
        return 0
    fi

    if (( ! I18N_LOADED )); then
        _i18n_load_locale "tr"
    fi

    local detail=""
    case "$st_up" in
        PASS|OK|SUCCESS)
            detail="${I18N_CHECK_PASS[$cid_up]:-}"
            ;;
        WARN|WARNING)
            detail="${I18N_CHECK_WARN[$cid_up]:-}"
            ;;
        FAIL|FAILURE|ERROR)
            detail="${I18N_CHECK_FAIL[$cid_up]:-}"
            ;;
    esac

    if [[ -n "$detail" ]]; then
        echo "$detail"
    else
        echo "$default_details"
    fi
}

# Get translated check remediation recommendation
# Usage: i18n_get_check_remediation <check_id> [default_rem]
i18n_get_check_remediation() {
    local check_id="${1:-}"
    local default_rem="${2:-}"
    local cid_up="${check_id:u}"

    if [[ "${CURRENT_LANG:-en}" != "tr" ]]; then
        echo "$default_rem"
        return 0
    fi

    if (( ! I18N_LOADED )); then
        _i18n_load_locale "tr"
    fi

    local rem="${I18N_CHECK_REM[$cid_up]:-}"
    if [[ -n "$rem" ]]; then
        echo "$rem"
    else
        echo "$default_rem"
    fi
}

# Get translated category name
# Usage: i18n_get_category_name <category_id>
i18n_get_category_name() {
    local cat="${1:-}"
    local cat_lower="${cat:l}"

    if [[ "${CURRENT_LANG:-en}" == "tr" ]]; then
        case "$cat_lower" in
            hardening)
                echo "Sistem Sıkılaştırma"
                ;;
            network)
                echo "Ağ Güvenliği"
                ;;
            secrets)
                echo "Gizli Bilgi ve Anahtar Güvenliği"
                ;;
            persistence)
                echo "Kalıcılık Denetimleri"
                ;;
            *)
                echo "${I18N_CACHE[ui.categories.$cat_lower]:-${I18N_CACHE[categories.$cat_lower]:-$cat}}"
                ;;
        esac
    else
        case "$cat_lower" in
            hardening)
                echo "Hardening"
                ;;
            network)
                echo "Network"
                ;;
            secrets)
                echo "Secrets"
                ;;
            persistence)
                echo "Persistence"
                ;;
            *)
                echo "$cat"
                ;;
        esac
    fi
}

# Get translated grade rating text
# Usage: i18n_get_rating_text <score>
i18n_get_rating_text() {
    local score="${1:-0.0}"
    local int_score=0
    if [[ "$score" =~ ^[0-9]+ ]]; then
        int_score=${score%%.*}
    fi

    if [[ "${CURRENT_LANG:-en}" == "tr" ]]; then
        if (( int_score >= 85 )); then
            echo "MÜKEMMEL / SIKILAŞTIRILMIŞ"
        elif (( int_score >= 70 )); then
            echo "İYİ / KABUL EDİLEBİLİR"
        elif (( int_score >= 50 )); then
            echo "ORTA / DİKKAT GEREKTİRİR"
        else
            echo "KRİTİK / ZAFİYETLİ"
        fi
    else
        if (( int_score >= 85 )); then
            echo "EXCELLENT / HARDENED"
        elif (( int_score >= 70 )); then
            echo "GOOD / ACCEPTABLE"
        elif (( int_score >= 50 )); then
            echo "FAIR / NEEDS ATTENTION"
        else
            echo "CRITICAL / VULNERABLE"
        fi
    fi
}
