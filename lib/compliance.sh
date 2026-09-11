#!/bin/zsh
# ==============================================================================
# macharden - lib/compliance.sh
# Enterprise Compliance & Regulatory Framework Mapping Engine
# Frameworks: CIS Apple macOS Benchmark, NIST SP 800-53 Rev 5, MITRE ATT&CK
# ==============================================================================

# Ensure execution under zsh or bash
if [ -z "${ZSH_VERSION:-}" ] && [ -z "${BASH_VERSION:-}" ]; then
    echo "Warning: compliance.sh is designed for zsh or bash" >&2
fi

# Fallback UI color variables if ui.sh was not pre-sourced
if [[ -z "${COLOR_BOLD:-}" ]]; then
    COLOR_RESET=$'\033[0m'
    COLOR_BOLD=$'\033[1m'
    COLOR_DIM=$'\033[2m'
    COLOR_RED=$'\033[31m'
    COLOR_GREEN=$'\033[32m'
    COLOR_YELLOW=$'\033[33m'
    COLOR_BLUE=$'\033[34m'
    COLOR_MAGENTA=$'\033[35m'
    COLOR_CYAN=$'\033[36m'
    COLOR_WHITE=$'\033[37m'
    COLOR_BRED=$'\033[91m'
    COLOR_BGREEN=$'\033[92m'
    COLOR_BYELLOW=$'\033[93m'
    COLOR_BCYAN=$'\033[96m'
    COLOR_BMAGENTA=$'\033[95m'
fi

# Resolve Base and Data directories defensively
if [[ -z "${BASE_DIR:-}" ]]; then
    _COMP_RESOLVED_DIR=""
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        _COMP_RESOLVED_DIR="$(cd "$(dirname "${(%):-%x}")/.." 2>/dev/null && pwd)"
    elif [[ -n "${BASH_SOURCE[0]:-}" ]]; then
        _COMP_RESOLVED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)"
    fi
    if [[ -n "$_COMP_RESOLVED_DIR" && -f "$_COMP_RESOLVED_DIR/data/compliance_mappings.json" ]]; then
        BASE_DIR="$_COMP_RESOLVED_DIR"
    elif [[ -f "./data/compliance_mappings.json" ]]; then
        BASE_DIR="$(pwd)"
    elif [[ -f "../data/compliance_mappings.json" ]]; then
        BASE_DIR="$(cd .. && pwd)"
    else
        BASE_DIR="<project_root>"
    fi
fi

COMPLIANCE_DATA_FILE="${BASE_DIR}/data/compliance_mappings.json"

# Global Compliance Metrics Variables
typeset -g CIS_COMPLIANCE_PCT="0.0"
typeset -g NIST_COMPLIANCE_PCT="0.0"
typeset -g MITRE_COVERAGE_PCT="0.0"

typeset -gi CIS_TOTAL_COUNT=0
typeset -gi CIS_PASS_COUNT=0
typeset -gi CIS_WARN_COUNT=0
typeset -gi CIS_FAIL_COUNT=0

typeset -gi NIST_TOTAL_COUNT=0
typeset -gi NIST_PASS_COUNT=0
typeset -gi NIST_WARN_COUNT=0
typeset -gi NIST_FAIL_COUNT=0

typeset -gi MITRE_TOTAL_COUNT=0
typeset -gi MITRE_DEFENDED_COUNT=0
typeset -gi MITRE_AT_RISK_COUNT=0

# Return compliance tags for a given check ID
# Usage: get_compliance_tags <check_id> [format: all|cis|nist|mitre|json]
get_compliance_tags() {
    local check_id="${1:-}"
    local format="${2:-all}"
    format="${format:l}"

    if [[ -z "$check_id" ]]; then
        echo ""
        return 1
    fi

    local data_file="$COMPLIANCE_DATA_FILE"
    if [[ ! -f "$data_file" ]]; then
        if [[ -f "./data/compliance_mappings.json" ]]; then
            data_file="./data/compliance_mappings.json"
        elif [[ -f "../data/compliance_mappings.json" ]]; then
            data_file="../data/compliance_mappings.json"
        fi
    fi

    if [[ ! -f "$data_file" ]]; then
        echo "N/A"
        return 1
    fi

    if command -v python3 >/dev/null 2>&1; then
        python3 -c '
import json, sys

check_id = sys.argv[1].upper()
fmt = sys.argv[2].lower()
data_file = sys.argv[3]

try:
    with open(data_file) as f:
        data = json.load(f)
    mappings = data.get("mappings", {})
    m = mappings.get(check_id)
    if not m:
        for k, v in mappings.items():
            if k.replace("-", "_").upper() == check_id.replace("-", "_"):
                m = v
                break

    if not m:
        print("N/A")
        sys.exit(0)

    cis_id = m.get("cis", {}).get("id", "N/A")
    nist_ctrls = ", ".join(m.get("nist", {}).get("controls", [])) or m.get("nist", {}).get("primary", "N/A")
    mitre_techs = ", ".join([t["id"] for t in m.get("mitre", {}).get("techniques", [])]) or m.get("mitre", {}).get("primary_technique", "N/A")

    if fmt == "cis":
        print(cis_id)
    elif fmt == "nist":
        print(nist_ctrls)
    elif fmt == "mitre":
        print(mitre_techs)
    elif fmt == "json":
        out = {
            "cis": cis_id,
            "nist": m.get("nist", {}).get("controls", [nist_ctrls]),
            "mitre": [t["id"] for t in m.get("mitre", {}).get("techniques", [])]
        }
        print(json.dumps(out))
    else:
        print(f"[CIS: {cis_id}] [NIST: {nist_ctrls}] [MITRE: {mitre_techs}]")
except Exception:
    print("N/A")
' "$check_id" "$format" "$data_file"
    else
        echo "[CIS: N/A] [NIST: N/A] [MITRE: N/A]"
    fi
}

# Calculate compliance metrics across all registered or executed checks
# Populates global variables: CIS_COMPLIANCE_PCT, NIST_COMPLIANCE_PCT, MITRE_COVERAGE_PCT
calculate_compliance_metrics() {
    local data_file="$COMPLIANCE_DATA_FILE"
    if [[ ! -f "$data_file" ]]; then
        if [[ -f "./data/compliance_mappings.json" ]]; then
            data_file="./data/compliance_mappings.json"
        elif [[ -f "../data/compliance_mappings.json" ]]; then
            data_file="../data/compliance_mappings.json"
        fi
    fi

    local n=${#RES_IDS[@]}
    if (( n == 0 )); then
        CIS_COMPLIANCE_PCT="100.0"
        NIST_COMPLIANCE_PCT="100.0"
        MITRE_COVERAGE_PCT="100.0"
        return 0
    fi

    if command -v python3 >/dev/null 2>&1; then
        local metrics_json
        metrics_json=$(python3 -c '
import json, sys

n = int(sys.argv[1])
idx = 2
ids = sys.argv[idx : idx + n]; idx += n
statuses = sys.argv[idx : idx + n]; idx += n
weights = sys.argv[idx : idx + n]; idx += n
data_file = sys.argv[idx]

try:
    with open(data_file) as f:
        mappings = json.load(f).get("mappings", {})
except Exception:
    mappings = {}

cis_pts_earned = 0.0
cis_pts_total = 0.0
cis_counts = {"pass": 0, "warn": 0, "fail": 0, "total": 0}

nist_pts_earned = 0.0
nist_pts_total = 0.0
nist_counts = {"pass": 0, "warn": 0, "fail": 0, "total": 0}

mitre_pts_earned = 0.0
mitre_pts_total = 0.0
mitre_counts = {"defended": 0, "at_risk": 0, "total": 0}

for i in range(n):
    cid = ids[i].upper()
    st = statuses[i].upper()
    try:
        w = float(weights[i])
    except ValueError:
        w = 5.0

    m = mappings.get(cid)
    if not m:
        for k, v in mappings.items():
            if k.replace("-", "_").upper() == cid.replace("-", "_"):
                m = v
                break

    if not m:
        continue

    # Skip neutral statuses (INFO and SUGG) so they do not penalize compliance score
    if st in ("INFO", "SUGG"):
        continue

    # CIS metrics
    if "cis" in m:
        cis_counts["total"] += 1
        cis_pts_total += w
        if st == "PASS":
            cis_counts["pass"] += 1
            cis_pts_earned += w
        elif st == "WARN":
            cis_counts["warn"] += 1
            cis_pts_earned += (w * 0.5)
        elif st == "FAIL":
            cis_counts["fail"] += 1

    # NIST metrics
    if "nist" in m:
        nist_counts["total"] += 1
        nist_pts_total += w
        if st == "PASS":
            nist_counts["pass"] += 1
            nist_pts_earned += w
        elif st == "WARN":
            nist_counts["warn"] += 1
            nist_pts_earned += (w * 0.5)
        elif st == "FAIL":
            nist_counts["fail"] += 1

    # MITRE metrics
    if "mitre" in m:
        mitre_counts["total"] += 1
        mitre_pts_total += w
        if st == "PASS":
            mitre_counts["defended"] += 1
            mitre_pts_earned += w
        else:
            mitre_counts["at_risk"] += 1
            if st == "WARN":
                mitre_pts_earned += (w * 0.5)

cis_pct = (cis_pts_earned / cis_pts_total * 100.0) if cis_pts_total > 0 else 100.0
nist_pct = (nist_pts_earned / nist_pts_total * 100.0) if nist_pts_total > 0 else 100.0
mitre_pct = (mitre_pts_earned / mitre_pts_total * 100.0) if mitre_pts_total > 0 else 100.0

res = {
    "cis_pct": f"{cis_pct:.1f}",
    "nist_pct": f"{nist_pct:.1f}",
    "mitre_pct": f"{mitre_pct:.1f}",
    "cis_total": cis_counts["total"],
    "cis_pass": cis_counts["pass"],
    "cis_warn": cis_counts["warn"],
    "cis_fail": cis_counts["fail"],
    "nist_total": nist_counts["total"],
    "nist_pass": nist_counts["pass"],
    "nist_warn": nist_counts["warn"],
    "nist_fail": nist_counts["fail"],
    "mitre_total": mitre_counts["total"],
    "mitre_defended": mitre_counts["defended"],
    "mitre_at_risk": mitre_counts["at_risk"]
}
print(json.dumps(res))
' "$n" "${RES_IDS[@]}" "${RES_STATUSES[@]}" "${RES_WEIGHTS[@]}" "$data_file")

        CIS_COMPLIANCE_PCT=$(echo "$metrics_json" | sed -n 's/.*"cis_pct": *"\([^"]*\)".*/\1/p')
        NIST_COMPLIANCE_PCT=$(echo "$metrics_json" | sed -n 's/.*"nist_pct": *"\([^"]*\)".*/\1/p')
        MITRE_COVERAGE_PCT=$(echo "$metrics_json" | sed -n 's/.*"mitre_pct": *"\([^"]*\)".*/\1/p')

        CIS_TOTAL_COUNT=$(echo "$metrics_json" | sed -n 's/.*"cis_total": *\([0-9]*\).*/\1/p')
        CIS_PASS_COUNT=$(echo "$metrics_json" | sed -n 's/.*"cis_pass": *\([0-9]*\).*/\1/p')
        CIS_WARN_COUNT=$(echo "$metrics_json" | sed -n 's/.*"cis_warn": *\([0-9]*\).*/\1/p')
        CIS_FAIL_COUNT=$(echo "$metrics_json" | sed -n 's/.*"cis_fail": *\([0-9]*\).*/\1/p')

        NIST_TOTAL_COUNT=$(echo "$metrics_json" | sed -n 's/.*"nist_total": *\([0-9]*\).*/\1/p')
        NIST_PASS_COUNT=$(echo "$metrics_json" | sed -n 's/.*"nist_pass": *\([0-9]*\).*/\1/p')
        NIST_WARN_COUNT=$(echo "$metrics_json" | sed -n 's/.*"nist_warn": *\([0-9]*\).*/\1/p')
        NIST_FAIL_COUNT=$(echo "$metrics_json" | sed -n 's/.*"nist_fail": *\([0-9]*\).*/\1/p')

        MITRE_TOTAL_COUNT=$(echo "$metrics_json" | sed -n 's/.*"mitre_total": *\([0-9]*\).*/\1/p')
        MITRE_DEFENDED_COUNT=$(echo "$metrics_json" | sed -n 's/.*"mitre_defended": *\([0-9]*\).*/\1/p')
        MITRE_AT_RISK_COUNT=$(echo "$metrics_json" | sed -n 's/.*"mitre_at_risk": *\([0-9]*\).*/\1/p')
    else
        CIS_COMPLIANCE_PCT="${HARDENING_INDEX:-100.0}"
        NIST_COMPLIANCE_PCT="${HARDENING_INDEX:-100.0}"
        MITRE_COVERAGE_PCT="${HARDENING_INDEX:-100.0}"
    fi
}

# Helper to format rating label from score
_compliance_rating_text() {
    local score="$1"
    local int_score=0
    if [[ "$score" =~ ^[0-9]+ ]]; then
        int_score=${score%%.*}
    fi
    if (( int_score >= 90 )); then
        echo "COMPLIANT / HARDENED"
    elif (( int_score >= 75 )); then
        echo "SUBSTANTIALLY COMPLIANT"
    elif (( int_score >= 60 )); then
        echo "PARTIALLY COMPLIANT / REVIEW"
    else
        echo "NON-COMPLIANT / DEFICIENT"
    fi
}

# Mini progress bar helper
_compliance_bar() {
    local score="${1:-0.0}"
    local width="${2:-20}"
    local int_score=0
    if [[ "$score" =~ ^[0-9]+ ]]; then
        int_score=${score%%.*}
    fi

    local filled=$(( (int_score * width) / 100 ))
    local empty=$(( width - filled ))
    (( filled < 0 )) && filled=0
    (( empty < 0 )) && empty=0

    local color="$COLOR_BGREEN"
    if (( int_score < 75 )); then
        color="$COLOR_BYELLOW"
    fi
    if (( int_score < 60 )); then
        color="$COLOR_BRED"
    fi

    local bar=""
    for (( b = 0; b < filled; b++ )); do bar+="█"; done
    for (( b = 0; b < empty; b++ )); do bar+="░"; done

    printf "%b[%s]%b %5.1f%%" "$color" "$bar" "$COLOR_RESET" "$score"
}

# Report executive compliance summary across CIS, NIST, and MITRE
# Usage: report_compliance_summary [format: term|markdown|json] [output_file]
report_compliance_summary() {
    local format="${1:-term}"
    local output_file="${2:-}"
    format="${format:l}"

    calculate_compliance_metrics

    local cis_rating nist_rating mitre_rating
    cis_rating=$(_compliance_rating_text "$CIS_COMPLIANCE_PCT")
    nist_rating=$(_compliance_rating_text "$NIST_COMPLIANCE_PCT")
    mitre_rating=$(_compliance_rating_text "$MITRE_COVERAGE_PCT")

    local current_time
    current_time=$(date "+%Y-%m-%d %H:%M:%S %Z")

    case "$format" in
        term)
            local output=""
            output+="\n"
            output+="${COLOR_BOLD}${COLOR_BCYAN}======================================================================${COLOR_RESET}\n"
            output+="               ${COLOR_BOLD}ENTERPRISE COMPLIANCE POSTURE SUMMARY${COLOR_RESET}\n"
            output+="${COLOR_BOLD}${COLOR_BCYAN}======================================================================${COLOR_RESET}\n"
            output+="${COLOR_DIM}Evaluation Date: ${current_time}${COLOR_RESET}\n\n"

            output+=$(printf "  ${COLOR_BOLD}%-32s${COLOR_RESET} " "CIS Apple macOS Benchmark:")
            output+="$(_compliance_bar "$CIS_COMPLIANCE_PCT" 24)  ${COLOR_BOLD}${cis_rating}${COLOR_RESET}\n"
            output+=$(printf "    ${COLOR_DIM}Passed: %d | Warnings: %d | Failed: %d (Total: %d controls)${COLOR_RESET}\n" \
                "$CIS_PASS_COUNT" "$CIS_WARN_COUNT" "$CIS_FAIL_COUNT" "$CIS_TOTAL_COUNT")
            output+="\n"

            output+=$(printf "  ${COLOR_BOLD}%-32s${COLOR_RESET} " "NIST SP 800-53 Rev. 5:")
            output+="$(_compliance_bar "$NIST_COMPLIANCE_PCT" 24)  ${COLOR_BOLD}${nist_rating}${COLOR_RESET}\n"
            output+=$(printf "    ${COLOR_DIM}Passed: %d | Warnings: %d | Failed: %d (Total: %d controls)${COLOR_RESET}\n" \
                "$NIST_PASS_COUNT" "$NIST_WARN_COUNT" "$NIST_FAIL_COUNT" "$NIST_TOTAL_COUNT")
            output+="\n"

            output+=$(printf "  ${COLOR_BOLD}%-32s${COLOR_RESET} " "MITRE ATT&CK Defense Coverage:")
            output+="$(_compliance_bar "$MITRE_COVERAGE_PCT" 24)  ${COLOR_BOLD}${mitre_rating}${COLOR_RESET}\n"
            output+=$(printf "    ${COLOR_DIM}Defended: %d | At Risk: %d (Total: %d techniques)${COLOR_RESET}\n" \
                "$MITRE_DEFENDED_COUNT" "$MITRE_AT_RISK_COUNT" "$MITRE_TOTAL_COUNT")

            output+="\n${COLOR_DIM}----------------------------------------------------------------------${COLOR_RESET}\n"
            output+="  ${COLOR_BOLD}Regulatory Framework Inspection Options:${COLOR_RESET}\n"
            output+="    • ${COLOR_BOLD}macharden --compliance cis${COLOR_RESET}    : Detailed CIS Apple macOS Benchmark audit\n"
            output+="    • ${COLOR_BOLD}macharden --compliance nist${COLOR_RESET}   : Detailed NIST SP 800-53 Rev 5 control matrix\n"
            output+="    • ${COLOR_BOLD}macharden --compliance mitre${COLOR_RESET}  : Adversarial MITRE ATT&CK technique mapping\n"
            output+="${COLOR_BOLD}${COLOR_BCYAN}======================================================================${COLOR_RESET}\n\n"

            if [[ -n "$output_file" ]]; then
                printf "%b" "$output" | sed -E $'s/\x1B\\[[0-9;]*[a-zA-Z]//g' > "$output_file"
                if [[ "${MACHAR_QUIET:-0}" -eq 0 ]]; then
                    printf "%b" "$output"
                    echo "${COLOR_BGREEN}[PASS] Compliance summary written to: ${output_file}${COLOR_RESET}"
                fi
            else
                printf "%b" "$output"
            fi
            ;;

        markdown)
            local md=""
            md+="# Enterprise Compliance & Security Framework Summary\n\n"
            md+="> **macharden Automated Regulatory Compliance Mapping**  \n"
            md+="> Evaluated on \`${current_time}\`\n\n"
            md+="---\n\n"
            md+="## Framework Posture Overview\n\n"
            md+="| Framework | Compliance Score | Status | Evaluated | Compliant / Defended | Warnings | Deficiencies |\n"
            md+="| :--- | :---: | :---: | :---: | :---: | :---: | :---: |\n"
            md+="| **CIS Apple macOS Benchmark** | **${CIS_COMPLIANCE_PCT}%** | ${cis_rating} | ${CIS_TOTAL_COUNT} | ${CIS_PASS_COUNT} | ${CIS_WARN_COUNT} | ${CIS_FAIL_COUNT} |\n"
            md+="| **NIST SP 800-53 Rev. 5** | **${NIST_COMPLIANCE_PCT}%** | ${nist_rating} | ${NIST_TOTAL_COUNT} | ${NIST_PASS_COUNT} | ${NIST_WARN_COUNT} | ${NIST_FAIL_COUNT} |\n"
            md+="| **MITRE ATT&CK (macOS Defense)** | **${MITRE_COVERAGE_PCT}%** | ${mitre_rating} | ${MITRE_TOTAL_COUNT} | ${MITRE_DEFENDED_COUNT} | - | ${MITRE_AT_RISK_COUNT} |\n\n"

            if [[ -n "$output_file" ]]; then
                printf "%b" "$md" > "$output_file"
                if [[ "${MACHAR_QUIET:-0}" -eq 0 ]]; then
                    printf "%b" "$md"
                fi
            else
                printf "%b" "$md"
            fi
            ;;

        json)
            local json_summary=""
            json_summary="{\n"
            json_summary+="  \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",\n"
            json_summary+="  \"compliance\": {\n"
            json_summary+="    \"cis\": {\n"
            json_summary+="      \"framework\": \"CIS Apple macOS Benchmark\",\n"
            json_summary+="      \"compliance_percentage\": ${CIS_COMPLIANCE_PCT},\n"
            json_summary+="      \"rating\": \"${cis_rating}\",\n"
            json_summary+="      \"total_controls\": ${CIS_TOTAL_COUNT},\n"
            json_summary+="      \"passed\": ${CIS_PASS_COUNT},\n"
            json_summary+="      \"warnings\": ${CIS_WARN_COUNT},\n"
            json_summary+="      \"failed\": ${CIS_FAIL_COUNT}\n"
            json_summary+="    },\n"
            json_summary+="    \"nist\": {\n"
            json_summary+="      \"framework\": \"NIST SP 800-53 Rev. 5\",\n"
            json_summary+="      \"compliance_percentage\": ${NIST_COMPLIANCE_PCT},\n"
            json_summary+="      \"rating\": \"${nist_rating}\",\n"
            json_summary+="      \"total_controls\": ${NIST_TOTAL_COUNT},\n"
            json_summary+="      \"passed\": ${NIST_PASS_COUNT},\n"
            json_summary+="      \"warnings\": ${NIST_WARN_COUNT},\n"
            json_summary+="      \"failed\": ${NIST_FAIL_COUNT}\n"
            json_summary+="    },\n"
            json_summary+="    \"mitre\": {\n"
            json_summary+="      \"framework\": \"MITRE ATT&CK Matrix for macOS\",\n"
            json_summary+="      \"defense_coverage_percentage\": ${MITRE_COVERAGE_PCT},\n"
            json_summary+="      \"rating\": \"${mitre_rating}\",\n"
            json_summary+="      \"total_techniques\": ${MITRE_TOTAL_COUNT},\n"
            json_summary+="      \"defended\": ${MITRE_DEFENDED_COUNT},\n"
            json_summary+="      \"at_risk\": ${MITRE_AT_RISK_COUNT}\n"
            json_summary+="    }\n"
            json_summary+="  }\n"
            json_summary+="}\n"

            if [[ -n "$output_file" ]]; then
                printf "%b" "$json_summary" > "$output_file"
                if [[ "${MACHAR_QUIET:-0}" -eq 0 ]]; then
                    printf "%b" "$json_summary"
                fi
            else
                printf "%b" "$json_summary"
            fi
            ;;
    esac
}

# Display detailed regulatory posture for CIS Apple macOS Benchmark
# Usage: report_compliance_cis [format] [output_file]
report_compliance_cis() {
    local format="${1:-term}"
    local output_file="${2:-}"
    local data_file="$COMPLIANCE_DATA_FILE"

    calculate_compliance_metrics
    local cis_rating
    cis_rating=$(_compliance_rating_text "$CIS_COMPLIANCE_PCT")

    if command -v python3 >/dev/null 2>&1; then
        local n=${#RES_IDS[@]}
        local report_out
        report_out=$(python3 -c '
import json, sys

fmt = sys.argv[1].lower()
pct = sys.argv[2]
rating = sys.argv[3]
data_file = sys.argv[4]
n = int(sys.argv[5])
idx = 6

ids = sys.argv[idx : idx + n]; idx += n
statuses = sys.argv[idx : idx + n]; idx += n
titles = sys.argv[idx : idx + n]; idx += n
details = sys.argv[idx : idx + n]; idx += n
remediations = sys.argv[idx : idx + n]; idx += n

try:
    with open(data_file) as f:
        mappings = json.load(f).get("mappings", {})
except Exception:
    mappings = {}

rows = []
sections = {}

for i in range(n):
    cid = ids[i].upper()
    st = statuses[i].upper()
    m = mappings.get(cid)
    if not m:
        for k, v in mappings.items():
            if k.replace("-", "_").upper() == cid.replace("-", "_"):
                m = v
                break

    if not m or "cis" not in m:
        continue

    cis_info = m["cis"]
    sec = cis_info.get("section", "General")
    if sec not in sections:
        sections[sec] = {"total": 0, "pass": 0, "warn": 0, "fail": 0}
    sections[sec]["total"] += 1
    sections[sec][st.lower()] = sections[sec].get(st.lower(), 0) + 1

    rows.append({
        "id": cid,
        "cis_id": cis_info.get("id", "N/A"),
        "section": sec,
        "title": cis_info.get("title", titles[i]),
        "status": st,
        "details": details[i],
        "remediation": remediations[i]
    })

def cis_sort_key(item):
    parts = item["cis_id"].split(".")
    res = []
    for p in parts:
        try: res.append(int(p))
        except ValueError: res.append(999)
    return res

rows.sort(key=cis_sort_key)

if fmt == "json":
    out = {
        "framework": "CIS Apple macOS Benchmark",
        "compliance_percentage": float(pct),
        "rating": rating,
        "sections": sections,
        "controls": rows
    }
    print(json.dumps(out, indent=2))
elif fmt == "markdown":
    print(f"# CIS Apple macOS Benchmark Compliance Report\n")
    print(f"### Compliance Score: **{pct}%** — *{rating}*\n")
    print("| Status | CIS ID | Check ID | Section | Recommendation Title | Finding |")
    print("| :---: | :--- | :--- | :--- | :--- | :--- |")
    for r in rows:
        st_badge = "🟢 PASS" if r["status"] == "PASS" else ("🟡 WARN" if r["status"] == "WARN" else "🔴 FAIL")
        r_cid = r["cis_id"]
        r_id = r["id"]
        r_sec = r["section"]
        r_title = r["title"]
        det = r.get("details", "").replace("|", "\\|").replace("\n", "<br>")
        print(f"| {st_badge} | `{r_cid}` | `{r_id}` | {r_sec} | {r_title} | {det} |")

    print("\n## Section Compliance Breakdown\n")
    print("| Section | Evaluated | Passed | Warnings | Deficiencies | Compliance |")
    print("| :--- | :---: | :---: | :---: | :---: | :---: |")
    for sec, c in sorted(sections.items()):
        p_cnt = c.get("pass", 0)
        w_cnt = c.get("warn", 0)
        f_cnt = c.get("fail", 0)
        t_cnt = c.get("total", 0)
        sec_score = ((p_cnt + 0.5 * w_cnt) / t_cnt) * 100 if t_cnt else 100
        print(f"| **{sec}** | {t_cnt} | {p_cnt} | {w_cnt} | {f_cnt} | {sec_score:.1f}% |")

    deficiencies = [r for r in rows if r["status"] in ("FAIL", "WARN")]
    if deficiencies:
        print("\n## Non-Compliant Recommendations & Remediation\n")
        for d in deficiencies:
            icon = "🔴" if d["status"] == "FAIL" else "🟡"
            d_cid = d["cis_id"]
            d_title = d["title"]
            d_id = d["id"]
            d_st = d["status"]
            d_det = d.get("details", "")
            d_rem = d.get("remediation", "")
            print(f"### {icon} [CIS {d_cid}] {d_title}")
            print(f"- **Check ID:** `{d_id}` | **Status:** **{d_st}**")
            print(f"- **Finding:** {d_det}")
            if d_rem:
                print(f"- **Remediation:**\n```bash\n{d_rem}\n```\n")
else:
    C_CYAN = "\033[96m"
    C_BOLD = "\033[1m"
    C_RESET = "\033[0m"
    C_GREEN = "\033[92m"
    C_YELLOW = "\033[93m"
    C_RED = "\033[91m"
    C_MAGENTA = "\033[95m"
    C_DIM = "\033[2m"

    pass_count = sum(1 for r in rows if r["status"] == "PASS")
    warn_count = sum(1 for r in rows if r["status"] == "WARN")
    fail_count = sum(1 for r in rows if r["status"] == "FAIL")

    print(f"\n{C_BOLD}{C_CYAN}======================================================================{C_RESET}")
    print(f"         {C_BOLD}CIS APPLE macOS BENCHMARK REGULATORY POSTURE{C_RESET}")
    print(f"{C_BOLD}{C_CYAN}======================================================================{C_RESET}")
    print(f"  {C_BOLD}Benchmark Standard:{C_RESET} CIS Apple macOS 14 Sonoma / 15 Sequoia Benchmark")
    print(f"  {C_BOLD}Compliance Score  :{C_RESET} {C_BOLD}{pct}%{C_RESET} ({rating})")
    print(f"  {C_BOLD}Evaluated Controls:{C_RESET} Total: {len(rows)} | Passed: {pass_count} | Warnings: {warn_count} | Deficiencies: {fail_count}\n")

    print(f"  {C_BOLD}{C_CYAN}CIS Benchmark Section Breakdown:{C_RESET}")
    print(f"  {C_DIM}--------------------------------------------------------------------{C_RESET}")
    for sec, c in sorted(sections.items()):
        p_cnt = c.get("pass", 0)
        w_cnt = c.get("warn", 0)
        f_cnt = c.get("fail", 0)
        t_cnt = c.get("total", 0)
        sec_score = ((p_cnt + 0.5 * w_cnt) / t_cnt) * 100 if t_cnt else 100
        sec_color = C_GREEN if sec_score >= 80 else (C_YELLOW if sec_score >= 60 else C_RED)
        print(f"    %-32s {sec_color}%5.1f%%{C_RESET} {C_DIM}(Pass: {p_cnt}, Warn: {w_cnt}, Fail: {f_cnt}){C_RESET}" % (sec, sec_score))

    print(f"\n  {C_BOLD}{C_CYAN}Individual CIS Control Audits:{C_RESET}")
    print(f"  {C_DIM}--------------------------------------------------------------------{C_RESET}")
    for r in rows:
        if r["status"] == "PASS":
            st_badge = f"{C_GREEN}[PASS]{C_RESET}"
        elif r["status"] == "WARN":
            st_badge = f"{C_YELLOW}[WARN]{C_RESET}"
        elif r["status"] == "SUGG":
            st_badge = f"{C_MAGENTA}[SUGG]{C_RESET}"
        elif r["status"] == "INFO":
            st_badge = f"{C_CYAN}[INFO]{C_RESET}"
        else:
            st_badge = f"{C_RED}[FAIL]{C_RESET}"

        print(f"  {st_badge} {C_BOLD}%-8s{C_RESET} %-8s %s" % (r["cis_id"], r["id"], r["title"]))
        d_text = r.get("details", "")
        r_text = r.get("remediation", "")
        if r["status"] != "PASS" and d_text:
            print(f"           {C_DIM}Finding:{C_RESET} {d_text}")
            if r_text:
                print(f"           {C_CYAN}Fix    :{C_RESET} {r_text}")

    print(f"{C_BOLD}{C_CYAN}======================================================================{C_RESET}\n")
' "$format" "$CIS_COMPLIANCE_PCT" "$cis_rating" "$data_file" \
            "$n" "${RES_IDS[@]}" "${RES_STATUSES[@]}" "${RES_TITLES[@]}" "${RES_DETAILS[@]}" "${RES_REMEDIATIONS[@]}")

        if [[ -n "$output_file" ]]; then
            if [[ "$format" == "term" ]]; then
                printf "%s\n" "$report_out" | sed -E $'s/\x1B\\[[0-9;]*[a-zA-Z]//g' > "$output_file"
            else
                printf "%s\n" "$report_out" > "$output_file"
            fi
            if [[ "${MACHAR_QUIET:-0}" -eq 0 ]]; then
                printf "%s\n" "$report_out"
            fi
        else
            printf "%s\n" "$report_out"
        fi
    else
        report_compliance_summary "$format" "$output_file"
    fi
}

# Display detailed regulatory posture for NIST SP 800-53 Rev. 5
# Usage: report_compliance_nist [format] [output_file]
report_compliance_nist() {
    local format="${1:-term}"
    local output_file="${2:-}"
    local data_file="$COMPLIANCE_DATA_FILE"

    calculate_compliance_metrics
    local nist_rating
    nist_rating=$(_compliance_rating_text "$NIST_COMPLIANCE_PCT")

    if command -v python3 >/dev/null 2>&1; then
        local n=${#RES_IDS[@]}
        local report_out
        report_out=$(python3 -c '
import json, sys

fmt = sys.argv[1].lower()
pct = sys.argv[2]
rating = sys.argv[3]
data_file = sys.argv[4]
n = int(sys.argv[5])
idx = 6

ids = sys.argv[idx : idx + n]; idx += n
statuses = sys.argv[idx : idx + n]; idx += n
titles = sys.argv[idx : idx + n]; idx += n
details = sys.argv[idx : idx + n]; idx += n
remediations = sys.argv[idx : idx + n]; idx += n

try:
    with open(data_file) as f:
        mappings = json.load(f).get("mappings", {})
except Exception:
    mappings = {}

rows = []
families = {}

for i in range(n):
    cid = ids[i].upper()
    st = statuses[i].upper()
    m = mappings.get(cid)
    if not m:
        for k, v in mappings.items():
            if k.replace("-", "_").upper() == cid.replace("-", "_"):
                m = v
                break

    if not m or "nist" not in m:
        continue

    nist_info = m["nist"]
    fam = nist_info.get("family", "General")
    if fam not in families:
        families[fam] = {"total": 0, "pass": 0, "warn": 0, "fail": 0}
    families[fam]["total"] += 1
    families[fam][st.lower()] = families[fam].get(st.lower(), 0) + 1

    ctrls = ", ".join(nist_info.get("controls", [])) or nist_info.get("primary", "N/A")

    rows.append({
        "id": cid,
        "primary_control": nist_info.get("primary", "N/A"),
        "all_controls": ctrls,
        "family": fam,
        "title": nist_info.get("title", titles[i]),
        "status": st,
        "details": details[i],
        "remediation": remediations[i]
    })

rows.sort(key=lambda x: x["primary_control"])

if fmt == "json":
    out = {
        "framework": "NIST SP 800-53 Rev. 5",
        "compliance_percentage": float(pct),
        "rating": rating,
        "control_families": families,
        "controls": rows
    }
    print(json.dumps(out, indent=2))
elif fmt == "markdown":
    print(f"# NIST SP 800-53 Rev. 5 Compliance Report\n")
    print(f"### Compliance Score: **{pct}%** — *{rating}*\n")
    print("| Status | Primary Control | Mapped Controls | Family | Control Title | Check ID |")
    print("| :---: | :--- | :--- | :--- | :--- | :--- |")
    for r in rows:
        st_badge = "🟢 PASS" if r["status"] == "PASS" else ("🟡 WARN" if r["status"] == "WARN" else "🔴 FAIL")
        r_ctrl = r["primary_control"]
        r_all = r["all_controls"]
        r_fam = r["family"]
        r_title = r["title"]
        r_id = r["id"]
        print(f"| {st_badge} | `{r_ctrl}` | {r_all} | {r_fam} | {r_title} | `{r_id}` |")

    print("\n## Control Family Compliance Breakdown\n")
    print("| Control Family | Evaluated | Passed | Warnings | Deficiencies | Compliance Score |")
    print("| :--- | :---: | :---: | :---: | :---: | :---: |\n")
    for fam, c in sorted(families.items()):
        p_cnt = c.get("pass", 0)
        w_cnt = c.get("warn", 0)
        f_cnt = c.get("fail", 0)
        t_cnt = c.get("total", 0)
        fscore = ((p_cnt + 0.5 * w_cnt) / t_cnt) * 100 if t_cnt else 100
        print(f"| **{fam}** | {t_cnt} | {p_cnt} | {w_cnt} | {f_cnt} | **{fscore:.1f}%** |")

    deficiencies = [r for r in rows if r["status"] in ("FAIL", "WARN")]
    if deficiencies:
        print("\n## Non-Compliant NIST Controls & Remediation Guidance\n")
        for d in deficiencies:
            icon = "🔴" if d["status"] == "FAIL" else "🟡"
            d_ctrl = d["primary_control"]
            d_title = d["title"]
            d_id = d["id"]
            d_all = d["all_controls"]
            d_det = d.get("details", "")
            d_rem = d.get("remediation", "")
            print(f"### {icon} [{d_ctrl}] {d_title}")
            print(f"- **Check ID:** `{d_id}` | **Mapped Controls:** {d_all}")
            print(f"- **Finding:** {d_det}")
            if d_rem:
                print(f"- **Remediation Action:**\n```bash\n{d_rem}\n```\n")
else:
    C_CYAN = "\033[96m"
    C_BOLD = "\033[1m"
    C_RESET = "\033[0m"
    C_GREEN = "\033[92m"
    C_YELLOW = "\033[93m"
    C_RED = "\033[91m"
    C_DIM = "\033[2m"

    pass_count = sum(1 for r in rows if r["status"] == "PASS")
    warn_count = sum(1 for r in rows if r["status"] == "WARN")
    fail_count = sum(1 for r in rows if r["status"] == "FAIL")

    print(f"\n{C_BOLD}{C_CYAN}======================================================================{C_RESET}")
    print(f"             {C_BOLD}NIST SP 800-53 Rev. 5 COMPLIANCE POSTURE{C_RESET}")
    print(f"{C_BOLD}{C_CYAN}======================================================================{C_RESET}")
    print(f"  {C_BOLD}Framework Standard:{C_RESET} NIST SP 800-53 Rev. 5 Security and Privacy Controls")
    print(f"  {C_BOLD}Compliance Score  :{C_RESET} {C_BOLD}{pct}%{C_RESET} ({rating})")
    print(f"  {C_BOLD}Evaluated Controls:{C_RESET} Total: {len(rows)} | Passed: {pass_count} | Warnings: {warn_count} | Deficiencies: {fail_count}\n")

    print(f"  {C_BOLD}{C_CYAN}NIST Control Family Breakdown:{C_RESET}")
    print(f"  {C_DIM}--------------------------------------------------------------------{C_RESET}")
    for fam, c in sorted(families.items()):
        p_cnt = c.get("pass", 0)
        w_cnt = c.get("warn", 0)
        f_cnt = c.get("fail", 0)
        t_cnt = c.get("total", 0)
        fscore = ((p_cnt + 0.5 * w_cnt) / t_cnt) * 100 if t_cnt else 100
        fam_color = C_GREEN if fscore >= 80 else (C_YELLOW if fscore >= 60 else C_RED)
        print(f"    %-36s {fam_color}%5.1f%%{C_RESET} {C_DIM}(Pass: {p_cnt}, Warn: {w_cnt}, Fail: {f_cnt}){C_RESET}" % (fam, fscore))

    print(f"\n  {C_BOLD}{C_CYAN}Individual NIST Control Audits:{C_RESET}")
    print(f"  {C_DIM}--------------------------------------------------------------------{C_RESET}")
    for r in rows:
        if r["status"] == "PASS":
            st_badge = f"{C_GREEN}[PASS]{C_RESET}"
        elif r["status"] == "WARN":
            st_badge = f"{C_YELLOW}[WARN]{C_RESET}"
        else:
            st_badge = f"{C_RED}[FAIL]{C_RESET}"

        print(f"  {st_badge} {C_BOLD}%-10s{C_RESET} %-8s %s" % (r["primary_control"], r["id"], r["title"]))
        d_text = r.get("details", "")
        r_text = r.get("remediation", "")
        if r["status"] != "PASS" and d_text:
            print(f"           {C_DIM}Finding:{C_RESET} {d_text}")
            if r_text:
                print(f"           {C_CYAN}Fix    :{C_RESET} {r_text}")

    print(f"{C_BOLD}{C_CYAN}======================================================================{C_RESET}\n")
' "$format" "$NIST_COMPLIANCE_PCT" "$nist_rating" "$data_file" \
            "$n" "${RES_IDS[@]}" "${RES_STATUSES[@]}" "${RES_TITLES[@]}" "${RES_DETAILS[@]}" "${RES_REMEDIATIONS[@]}")

        if [[ -n "$output_file" ]]; then
            if [[ "$format" == "term" ]]; then
                printf "%s\n" "$report_out" | sed -E $'s/\x1B\\[[0-9;]*[a-zA-Z]//g' > "$output_file"
            else
                printf "%s\n" "$report_out" > "$output_file"
            fi
            if [[ "${MACHAR_QUIET:-0}" -eq 0 ]]; then
                printf "%s\n" "$report_out"
            fi
        else
            printf "%s\n" "$report_out"
        fi
    else
        report_compliance_summary "$format" "$output_file"
    fi
}

# Display detailed regulatory posture for MITRE ATT&CK Matrix for macOS
# Usage: report_compliance_mitre [format] [output_file]
report_compliance_mitre() {
    local format="${1:-term}"
    local output_file="${2:-}"
    local data_file="$COMPLIANCE_DATA_FILE"

    calculate_compliance_metrics
    local mitre_rating
    mitre_rating=$(_compliance_rating_text "$MITRE_COVERAGE_PCT")

    if command -v python3 >/dev/null 2>&1; then
        local n=${#RES_IDS[@]}
        local report_out
        report_out=$(python3 -c '
import json, sys

fmt = sys.argv[1].lower()
pct = sys.argv[2]
rating = sys.argv[3]
data_file = sys.argv[4]
n = int(sys.argv[5])
idx = 6

ids = sys.argv[idx : idx + n]; idx += n
statuses = sys.argv[idx : idx + n]; idx += n
titles = sys.argv[idx : idx + n]; idx += n
details = sys.argv[idx : idx + n]; idx += n
remediations = sys.argv[idx : idx + n]; idx += n

try:
    with open(data_file) as f:
        mappings = json.load(f).get("mappings", {})
except Exception:
    mappings = {}

rows = []
tactics = {}

for i in range(n):
    cid = ids[i].upper()
    st = statuses[i].upper()
    m = mappings.get(cid)
    if not m:
        for k, v in mappings.items():
            if k.replace("-", "_").upper() == cid.replace("-", "_"):
                m = v
                break

    if not m or "mitre" not in m:
        continue

    mitre_info = m["mitre"]
    for tac in mitre_info.get("tactics", ["General"]):
        if tac not in tactics:
            tactics[tac] = {"total": 0, "defended": 0, "at_risk": 0}
        tactics[tac]["total"] += 1
        if st == "PASS":
            tactics[tac]["defended"] += 1
        else:
            tactics[tac]["at_risk"] += 1

    tech_names = [t["id"] + " (" + t["name"] + ")" for t in mitre_info.get("techniques", [])]
    tech_str = "; ".join(tech_names) or mitre_info.get("primary_technique", "N/A")

    rows.append({
        "id": cid,
        "primary_technique": mitre_info.get("primary_technique", "N/A"),
        "techniques": tech_str,
        "tactics": ", ".join(mitre_info.get("tactics", [])),
        "title": titles[i],
        "status": st,
        "defended": (st == "PASS"),
        "details": details[i],
        "remediation": remediations[i]
    })

rows.sort(key=lambda x: x["primary_technique"])

if fmt == "json":
    out = {
        "framework": "MITRE ATT&CK Matrix for macOS",
        "defense_coverage_percentage": float(pct),
        "rating": rating,
        "tactics": tactics,
        "techniques": rows
    }
    print(json.dumps(out, indent=2))
elif fmt == "markdown":
    print(f"# MITRE ATT&CK (macOS) Threat Posture Report\n")
    print(f"### Threat Defense Coverage: **{pct}%** — *{rating}*\n")
    print("| Posture | Technique ID | Primary Tactic | Hardening Check | Adversarial Technique Name |")
    print("| :---: | :--- | :--- | :--- | :--- |")
    for r in rows:
        badge = "🟢 DEFENDED" if r["defended"] else "🔴 AT RISK"
        r_tech = r["primary_technique"]
        r_tac = r["tactics"]
        r_id = r["id"]
        r_all_tech = r["techniques"]
        print(f"| {badge} | `{r_tech}` | {r_tac} | `{r_id}` | {r_all_tech} |")

    print("\n## ATT&CK Tactic Defense Breakdown\n")
    print("| Tactic | Evaluated Techniques | Defended | At Risk | Coverage Rate |")
    print("| :--- | :---: | :---: | :---: | :---: |")
    for tac, c in sorted(tactics.items()):
        d_cnt = c.get("defended", 0)
        ar_cnt = c.get("at_risk", 0)
        t_cnt = c.get("total", 0)
        cov = (d_cnt / t_cnt) * 100 if t_cnt else 100
        print(f"| **{tac}** | {t_cnt} | {d_cnt} | {ar_cnt} | **{cov:.1f}%** |")

    at_risk = [r for r in rows if not r["defended"]]
    if at_risk:
        print("\n## At-Risk Techniques & Mitigation Strategies\n")
        for ar in at_risk:
            ar_tech = ar["primary_technique"]
            ar_all = ar["techniques"]
            ar_id = ar["id"]
            ar_title = ar["title"]
            ar_tac = ar["tactics"]
            ar_det = ar.get("details", "")
            ar_rem = ar.get("remediation", "")
            print(f"### 🔴 [{ar_tech}] {ar_all}")
            print(f"- **Associated Control:** `{ar_id}` ({ar_title})")
            print(f"- **Tactic:** {ar_tac}")
            print(f"- **Finding:** {ar_det}")
            if ar_rem:
                print(f"- **Defensive Countermeasure:**\n```bash\n{ar_rem}\n```\n")
else:
    C_CYAN = "\033[96m"
    C_BOLD = "\033[1m"
    C_RESET = "\033[0m"
    C_GREEN = "\033[92m"
    C_YELLOW = "\033[93m"
    C_RED = "\033[91m"
    C_DIM = "\033[2m"

    defended_cnt = sum(1 for r in rows if r.get("defended"))
    at_risk_cnt = sum(1 for r in rows if not r.get("defended"))

    print(f"\n{C_BOLD}{C_CYAN}======================================================================{C_RESET}")
    print(f"              {C_BOLD}MITRE ATT&CK MATRIX FOR macOS POSTURE{C_RESET}")
    print(f"{C_BOLD}{C_CYAN}======================================================================{C_RESET}")
    print(f"  {C_BOLD}Matrix Standard   :{C_RESET} MITRE Enterprise ATT&CK (macOS Platform v14.1)")
    print(f"  {C_BOLD}Threat Coverage   :{C_RESET} {C_BOLD}{pct}%{C_RESET} ({rating})")
    print(f"  {C_BOLD}Technique Posture :{C_RESET} Total: {len(rows)} | Defended: {defended_cnt} | At Risk: {at_risk_cnt}\n")

    print(f"  {C_BOLD}{C_CYAN}MITRE ATT&CK Tactic Breakdown:{C_RESET}")
    print(f"  {C_DIM}--------------------------------------------------------------------{C_RESET}")
    for tac, c in sorted(tactics.items()):
        d_cnt = c.get("defended", 0)
        t_cnt = c.get("total", 0)
        cov = (d_cnt / t_cnt) * 100 if t_cnt else 100
        tac_color = C_GREEN if cov >= 80 else (C_YELLOW if cov >= 60 else C_RED)
        print(f"    %-28s {tac_color}%5.1f%%{C_RESET} {C_DIM}(Defended: {d_cnt}/{t_cnt}){C_RESET}" % (tac, cov))

    print(f"\n  {C_BOLD}{C_CYAN}Technique Defense Status:{C_RESET}")
    print(f"  {C_DIM}--------------------------------------------------------------------{C_RESET}")
    for r in rows:
        if r["defended"]:
            st_badge = f"{C_GREEN}[DEFENDED]{C_RESET}"
        else:
            st_badge = f"{C_RED}[AT RISK ]{C_RESET}"

        print(f"  {st_badge} {C_BOLD}%-12s{C_RESET} %-8s %s" % (r["primary_technique"], r["id"], r["title"]))
        d_text = r.get("details", "")
        r_text = r.get("remediation", "")
        if not r["defended"] and d_text:
            print(f"               {C_DIM}Finding:{C_RESET} {d_text}")
            if r_text:
                print(f"               {C_CYAN}Fix    :{C_RESET} {r_text}")

    print(f"{C_BOLD}{C_CYAN}======================================================================{C_RESET}\n")
' "$format" "$MITRE_COVERAGE_PCT" "$mitre_rating" "$data_file" \
            "$n" "${RES_IDS[@]}" "${RES_STATUSES[@]}" "${RES_TITLES[@]}" "${RES_DETAILS[@]}" "${RES_REMEDIATIONS[@]}")

        if [[ -n "$output_file" ]]; then
            if [[ "$format" == "term" ]]; then
                printf "%s\n" "$report_out" | sed -E $'s/\x1B\\[[0-9;]*[a-zA-Z]//g' > "$output_file"
            else
                printf "%s\n" "$report_out" > "$output_file"
            fi
            if [[ "${MACHAR_QUIET:-0}" -eq 0 ]]; then
                printf "%s\n" "$report_out"
            fi
        else
            printf "%s\n" "$report_out"
        fi
    else
        report_compliance_summary "$format" "$output_file"
    fi
}

# Main dispatcher for CLI --compliance flag
# Usage: report_compliance_framework <framework: cis|nist|mitre|all> [format] [output_file]
report_compliance_framework() {
    local framework="${1:-all}"
    local format="${2:-term}"
    local output_file="${3:-}"
    framework="${framework:l}"

    case "$framework" in
        cis)
            report_compliance_cis "$format" "$output_file"
            ;;
        nist)
            report_compliance_nist "$format" "$output_file"
            ;;
        mitre)
            report_compliance_mitre "$format" "$output_file"
            ;;
        all|"")
            report_compliance_summary "$format" "$output_file"
            if [[ "$format" == "term" ]]; then
                report_compliance_cis "$format" ""
                report_compliance_nist "$format" ""
                report_compliance_mitre "$format" ""
            fi
            ;;
        *)
            echo "Error: Unknown compliance framework '$framework'. Available: cis, nist, mitre, all" >&2
            return 1
            ;;
    esac
}
