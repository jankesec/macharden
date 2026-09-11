#!/bin/zsh
# ==============================================================================
# macharden - lib/report.sh
# Multi-format reporting engine: Terminal summary, GitHub Markdown, and JSON
# ==============================================================================

# Helper to determine human-readable rating from score
_get_rating_text() {
    local score="$1"
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

# Terminal executive report
report_terminal() {
    echo ""
    echo "${COLOR_BOLD}${COLOR_BCYAN}======================================================================${COLOR_RESET}"
    echo "                     ${COLOR_BOLD}EXECUTIVE AUDIT SUMMARY${COLOR_RESET}"
    echo "${COLOR_BOLD}${COLOR_BCYAN}======================================================================${COLOR_RESET}"
    echo ""

    ui_score_bar "$HARDENING_INDEX"
    echo ""

    printf "  ${COLOR_BOLD}%-24s${COLOR_RESET} %s\n" "Total Checks Audited:" "${COLOR_BOLD}${COUNT_TOTAL}${COLOR_RESET}"
    printf "  ${COLOR_BOLD}%-24s${COLOR_RESET} %b\n" "Passed Checks:" "${COLOR_BGREEN}${COUNT_PASS}${COLOR_RESET}"
    printf "  ${COLOR_BOLD}%-24s${COLOR_RESET} %b\n" "Warnings:" "${COLOR_BYELLOW}${COUNT_WARN}${COLOR_RESET}"
    printf "  ${COLOR_BOLD}%-24s${COLOR_RESET} %b\n" "Failed Checks:" "${COLOR_BRED}${COUNT_FAIL}${COLOR_RESET}"
    printf "  ${COLOR_BOLD}%-24s${COLOR_RESET} %b\n" "Informational:" "${COLOR_BCYAN}${COUNT_INFO}${COLOR_RESET}"
    printf "  ${COLOR_BOLD}%-24s${COLOR_RESET} %b\n" "Suggestions:" "${COLOR_BMAGENTA}${COUNT_SUGG}${COLOR_RESET}"
    printf "  ${COLOR_BOLD}%-24s${COLOR_RESET} %.1f / %.1f\n" "Score Points Earned:" "$EARNED_POINTS" "$TOTAL_POSSIBLE_POINTS"
    echo ""

    # Check for FAIL and WARN items
    local n=${#RES_IDS[@]}
    local has_recs=0
    for (( i = 1; i <= n; i++ )); do
        local st="${RES_STATUSES[i]}"
        if [[ "$st" == "FAIL" || "$st" == "WARN" ]]; then
            has_recs=1
            break
        fi
    done

    if (( has_recs )); then
        echo "${COLOR_BOLD}${COLOR_BYELLOW}▶ High Priority Remediation Actions:${COLOR_RESET}"
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

                    local badge=""
                    if [[ "$st" == "FAIL" ]]; then
                        badge="${COLOR_BRED}${COLOR_BOLD}[FAIL]${COLOR_RESET}"
                    else
                        badge="${COLOR_BYELLOW}${COLOR_BOLD}[WARN]${COLOR_RESET}"
                    fi

                    printf "  %b  ${COLOR_BOLD}%-10s${COLOR_RESET} %s ${COLOR_DIM}(Weight: %s, Category: %s)${COLOR_RESET}\n" \
                        "$badge" "$id" "$title" "$weight" "$cat"
                    if [[ -n "$details" ]]; then
                        printf "        ${COLOR_DIM}Finding:${COLOR_RESET} %s\n" "$details"
                    fi
                    if [[ -n "$rem" ]]; then
                        printf "        ${COLOR_BCYAN}Fix:${COLOR_RESET}     ${COLOR_WHITE}%s${COLOR_RESET}\n" "$rem"
                    fi
                    echo ""
                fi
            done
        done
        echo "${COLOR_DIM}----------------------------------------------------------------------${COLOR_RESET}"
        printf "  ${COLOR_BOLD}${COLOR_BGREEN}Remediation Options:${COLOR_RESET}\n"
        printf "    • Run with ${COLOR_BOLD}--fix${COLOR_RESET} to interactively apply available remediation fixes.\n"
        printf "    • Run with ${COLOR_BOLD}--generate-fix [file]${COLOR_RESET} to generate an executable shell script.\n"
    else
        echo "  ${COLOR_BGREEN}${COLOR_BOLD}✔ Security posture is excellent. No failed checks or warnings detected.${COLOR_RESET}"
    fi
    echo ""
}

# Generate GitHub-flavored Markdown report
report_markdown() {
    local output_file="${1:-}"
    local version="${MACHAR_VERSION:-1.0.0}"
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

    local points_display
    points_display=$(printf "%.1f / %.1f" "$EARNED_POINTS" "$TOTAL_POSSIBLE_POINTS")

    local md_content=""
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

### Hardening Index: **${HARDENING_INDEX}%** — *${rating}*

| Metric | Count / Value | Status |
| :--- | :---: | :---: |
| **Hardening Score** | **${HARDENING_INDEX}%** | **${rating}** |
| **Total Checks Audited** | **${COUNT_TOTAL}** | - |
| **Passed Checks** | **${COUNT_PASS}** | 🟢 PASS |
| **Warnings** | **${COUNT_WARN}** | 🟡 WARN |
| **Failed Checks** | **${COUNT_FAIL}** | 🔴 FAIL |
| **Informational** | **${COUNT_INFO}** | 🔵 INFO |
| **Suggestions** | **${COUNT_SUGG}** | 🟣 SUGG |
| **Earned Score Points** | **${points_display}** | - |

---

## 3. Comprehensive Audit Results

| Status | ID | Category | Check Title | Weight | Details |
| :---: | :--- | :--- | :--- | :---: | :--- |
"

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
        case "$st" in
            PASS) status_badge="🟢 PASS" ;;
            WARN) status_badge="🟡 WARN" ;;
            FAIL) status_badge="🔴 FAIL" ;;
            INFO) status_badge="🔵 INFO" ;;
            SUGG) status_badge="🟣 SUGG" ;;
            *)    status_badge="⚪ $st" ;;
        esac

        md_content+="${status_badge} | \`${id}\` | \`${cat}\` | ${title} | ${weight} | ${details:-N/A}
"
    done

    md_content+="
---

## 4. Remediation Playbook

"

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
        fi
    done

    if (( ! has_remediation )); then
        md_content+="*No critical remediation commands required. All audited security controls meet requirements.*
"
    fi

    md_content+="
---
*Report generated automatically by [macharden](https://github.com/macharden/macharden).*
"

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
    local version="${MACHAR_VERSION:-1.0.0}"
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

    # Build checks array via python3 if available for 100% strict JSON conformity
    if command -v python3 >/dev/null 2>&1; then
        local n=${#RES_IDS[@]}
        local json_doc
        json_doc=$(python3 -c "
import sys, json

n = int(sys.argv[1])
idx = 2

ids = sys.argv[idx : idx + n]; idx += n
cats = sys.argv[idx : idx + n]; idx += n
titles = sys.argv[idx : idx + n]; idx += n
statuses = sys.argv[idx : idx + n]; idx += n
weights = sys.argv[idx : idx + n]; idx += n
details = sys.argv[idx : idx + n]; idx += n
remediations = sys.argv[idx : idx + n]; idx += n

checks = []
for i in range(n):
    try:
        w = float(weights[i]) if '.' in weights[i] else int(weights[i])
    except ValueError:
        w = 5
    checks.append({
        'id': ids[i],
        'category': cats[i],
        'title': titles[i],
        'status': statuses[i],
        'weight': w,
        'details': details[i],
        'remediation': remediations[i]
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
            "$TOTAL_POSSIBLE_POINTS"
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
            json_doc+="      \"remediation\": \"${r}\"\n"
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
