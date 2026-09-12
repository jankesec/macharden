#!/bin/zsh
# ==============================================================================
# macharden - lib/report_sarif.sh
# OASIS SARIF v2.1.0 Report Generator (Static Analysis Results Interchange Format)
# Standard: OASIS Standard SARIF v2.1.0
# Schema: https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json
# Driver: macharden v1.3.0
# ==============================================================================

# Ensure execution under zsh or bash
if [ -z "${ZSH_VERSION:-}" ] && [ -z "${BASH_VERSION:-}" ]; then
    echo "Warning: report_sarif.sh is designed for zsh or bash" >&2
fi

# Fallback UI helpers if not sourced
if ! typeset -f ui_success >/dev/null 2>&1; then
    ui_success() { echo "✔ $1"; }
    ui_error() { echo "✖ Error: $1" >&2; }
fi

# ==============================================================================
# report_sarif [output_file]
# Generates a 100% valid OASIS SARIF v2.1.0 JSON report.
# ==============================================================================
report_sarif() {
    local output_file="${1:-}"
    local driver_name="macharden"
    local driver_version="1.3.0"
    local current_time
    current_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Resolve compliance mappings data file
    local comp_file=""
    if [[ -n "${COMPLIANCE_DATA_FILE:-}" && -f "$COMPLIANCE_DATA_FILE" ]]; then
        comp_file="$COMPLIANCE_DATA_FILE"
    elif [[ -n "${BASE_DIR:-}" && -f "$BASE_DIR/data/compliance_mappings.json" ]]; then
        comp_file="$BASE_DIR/data/compliance_mappings.json"
    elif [[ -f "./data/compliance_mappings.json" ]]; then
        comp_file="./data/compliance_mappings.json"
    elif [[ -f "../data/compliance_mappings.json" ]]; then
        comp_file="../data/compliance_mappings.json"
    else
        local script_dir
        if [[ -n "${ZSH_VERSION:-}" ]]; then
            script_dir="$(cd "$(dirname "${(%):-%x}")/.." 2>/dev/null && pwd)"
        elif [[ -n "${BASH_SOURCE[0]:-}" ]]; then
            script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)"
        fi
        if [[ -n "$script_dir" && -f "$script_dir/data/compliance_mappings.json" ]]; then
            comp_file="$script_dir/data/compliance_mappings.json"
        fi
    fi

    # Determine all registered check IDs and rules
    # If REG_IDS is empty, fallback to RES_IDS
    local reg_n=${#REG_IDS[@]}
    local res_n=${#RES_IDS[@]}

    local sarif_json
    sarif_json=$(python3 -c '
import sys, json, os, re

driver_name = sys.argv[1]
driver_version = sys.argv[2]
current_time = sys.argv[3]
comp_file = sys.argv[4]

idx = 5
reg_count = int(sys.argv[idx]); idx += 1
reg_ids = sys.argv[idx : idx + reg_count]; idx += reg_count
reg_cats = sys.argv[idx : idx + reg_count]; idx += reg_count
reg_titles = sys.argv[idx : idx + reg_count]; idx += reg_count
reg_weights = sys.argv[idx : idx + reg_count]; idx += reg_count

res_count = int(sys.argv[idx]); idx += 1
res_ids = sys.argv[idx : idx + res_count]; idx += res_count
res_cats = sys.argv[idx : idx + res_count]; idx += res_count
res_titles = sys.argv[idx : idx + res_count]; idx += res_count
res_statuses = sys.argv[idx : idx + res_count]; idx += res_count
res_weights = sys.argv[idx : idx + res_count]; idx += res_count
res_details = sys.argv[idx : idx + res_count]; idx += res_count
res_remediations = sys.argv[idx : idx + res_count]; idx += res_count

# Load compliance mappings
comp_map = {}
if comp_file and os.path.isfile(comp_file):
    try:
        with open(comp_file, "r", encoding="utf-8") as f:
            comp_map = json.load(f).get("mappings", {})
    except Exception:
        comp_map = {}

# Map of evaluated checks
eval_map = {}
for i in range(res_count):
    eval_map[res_ids[i]] = {
        "category": res_cats[i],
        "title": res_titles[i],
        "status": res_statuses[i],
        "weight": res_weights[i],
        "details": res_details[i],
        "remediation": res_remediations[i]
    }

# Build unified unique list of rules from registered checks (and any evaluated checks)
rule_ids_ordered = []
rule_meta = {}

for i in range(reg_count):
    cid = reg_ids[i]
    if cid and cid not in rule_meta:
        rule_ids_ordered.append(cid)
        try:
            w = float(reg_weights[i]) if "." in reg_weights[i] else int(reg_weights[i])
        except Exception:
            w = 5
        rule_meta[cid] = {
            "id": cid,
            "category": reg_cats[i],
            "title": reg_titles[i],
            "weight": w
        }

for i in range(res_count):
    cid = res_ids[i]
    if cid and cid not in rule_meta:
        rule_ids_ordered.append(cid)
        try:
            w = float(res_weights[i]) if "." in res_weights[i] else int(res_weights[i])
        except Exception:
            w = 5
        rule_meta[cid] = {
            "id": cid,
            "category": res_cats[i],
            "title": res_titles[i],
            "weight": w
        }

# Construct SARIF rules array
sarif_rules = []
rule_id_to_index = {}

for index, cid in enumerate(rule_ids_ordered):
    meta = rule_meta[cid]
    cat = meta["category"]
    title = meta["title"]
    weight = meta["weight"]

    # Alphanumeric camelCase rule name
    clean_name = re.sub(r"[^a-zA-Z0-9]", "", title)
    if not clean_name:
        clean_cid = cid.replace("-", "_")
        clean_name = f"Check{clean_cid}"

    # Determine defaultConfiguration level:
    # error for FAIL, warning for WARN, note for INFO / PASS
    evaluated = eval_map.get(cid)
    if evaluated:
        st = evaluated["status"].upper()
        if st == "FAIL":
            rule_level = "error"
        elif st == "WARN":
            rule_level = "warning"
        else:
            rule_level = "note"
    else:
        if weight >= 7:
            rule_level = "error"
        elif weight >= 5:
            rule_level = "warning"
        else:
            rule_level = "note"

    # Gather compliance info & tags
    comp = comp_map.get(cid, {})
    tags = ["security", "configuration", cat.lower()]

    cis_info = comp.get("cis", {})
    if cis_info and cis_info.get("id"):
        cis_id_val = cis_info.get("id")
        tags.append(f"cis:{cis_id_val}")

    nist_info = comp.get("nist", {})
    if nist_info and nist_info.get("controls"):
        for c in nist_info["controls"]:
            tags.append(f"nist:{c}")

    mitre_info = comp.get("mitre", {})
    if mitre_info:
        for tech in mitre_info.get("techniques", []):
            tid = tech.get("id")
            if tid:
                tags.append(f"mitre:{tid}")

    # Remove duplicates while preserving order
    unique_tags = []
    for t in tags:
        if t not in unique_tags:
            unique_tags.append(t)

    # Markdown Help Text
    help_md_lines = [
        f"### {title} (`{cid}`)",
        "",
        f"- **Category**: {cat.capitalize()}",
        f"- **Weight**: {weight} / 10",
        f"- **Default Severity**: {rule_level.upper()}",
        ""
    ]

    if cis_info and cis_info.get("id"):
        cis_id_val = cis_info.get("id", "")
        cis_title_val = cis_info.get("title", "")
        help_md_lines.append(f"- **CIS Benchmark**: §{cis_id_val} ({cis_title_val})")
    if nist_info and nist_info.get("controls"):
        nist_ctrls = ", ".join(nist_info.get("controls", []))
        help_md_lines.append(f"- **NIST SP 800-53**: {nist_ctrls}")
    if mitre_info and mitre_info.get("primary_technique"):
        mitre_tech = mitre_info.get("primary_technique", "")
        help_md_lines.append(f"- **MITRE ATT&CK**: {mitre_tech}")

    rem_cmd = evaluated.get("remediation", "") if evaluated else ""
    if rem_cmd:
        help_md_lines.extend([
            "",
            "#### Remediation Command:",
            "```bash",
            rem_cmd,
            "```"
        ])

    help_text = f"{title} ({cid})\nCategory: {cat}\nWeight: {weight}"
    if rem_cmd:
        help_text += f"\nRemediation: {rem_cmd}"

    full_desc = f"{title} - macOS security hardening control ({cat.capitalize()} category)."
    if evaluated and evaluated.get("details"):
        eval_det = evaluated.get("details", "")
        full_desc = f"{title}: {eval_det}"

    rule_obj = {
        "id": cid,
        "name": clean_name,
        "shortDescription": {
            "text": title
        },
        "fullDescription": {
            "text": full_desc
        },
        "help": {
            "text": help_text,
            "markdown": "\n".join(help_md_lines)
        },
        "defaultConfiguration": {
            "level": rule_level
        },
        "properties": {
            "category": cat,
            "weight": weight,
            "precision": "very-high",
            "security-severity": f"{float(weight):.1f}",
            "tags": unique_tags
        }
    }

    sarif_rules.append(rule_obj)
    rule_id_to_index[cid] = index

# Construct SARIF results array (only for FAIL and WARN checks)
sarif_results = []
for i in range(res_count):
    cid = res_ids[i]
    st = res_statuses[i].upper()
    if st not in ("FAIL", "WARN"):
        continue

    cat = res_cats[i]
    title = res_titles[i]
    det = res_details[i]
    rem = res_remediations[i]
    w = res_weights[i]

    res_level = "error" if st == "FAIL" else "warning"
    r_idx = rule_id_to_index.get(cid, 0)
    msg_text = det if det else f"Security control {title} ({cid}) failed verification."

    result_obj = {
        "ruleId": cid,
        "ruleIndex": r_idx,
        "level": res_level,
        "message": {
            "text": msg_text
        },
        "locations": [
            {
                "physicalLocation": {
                    "artifactLocation": {
                        "uri": "macOS/System/Configuration"
                    },
                    "region": {
                        "startLine": 1
                    }
                },
                "logicalLocations": [
                    {
                        "name": cat,
                        "kind": "category"
                    }
                ]
            }
        ],
        "properties": {
            "status": st,
            "category": cat,
            "weight": w,
            "remediation": rem
        }
    }

    if rem:
        result_obj["fixes"] = [
            {
                "description": {
                    "text": f"Remediate {cid} via: {rem}"
                }
            }
        ]

    sarif_results.append(result_obj)

# Construct top-level OASIS SARIF v2.1.0 document
sarif_doc = {
    "$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
    "version": "2.1.0",
    "runs": [
        {
            "tool": {
                "driver": {
                    "name": driver_name,
                    "version": driver_version,
                    "informationUri": "https://github.com/macharden/macharden",
                    "rules": sarif_rules
                }
            },
            "invocations": [
                {
                    "executionSuccessful": True,
                    "endTimeUtc": current_time
                }
            ],
            "results": sarif_results
        }
    ]
}

print(json.dumps(sarif_doc, indent=2))
' \
        "$driver_name" \
        "$driver_version" \
        "$current_time" \
        "$comp_file" \
        "$reg_n" \
        "${REG_IDS[@]}" \
        "${REG_CATEGORIES[@]}" \
        "${REG_TITLES[@]}" \
        "${REG_WEIGHTS[@]}" \
        "$res_n" \
        "${RES_IDS[@]}" \
        "${RES_CATEGORIES[@]}" \
        "${RES_TITLES[@]}" \
        "${RES_STATUSES[@]}" \
        "${RES_WEIGHTS[@]}" \
        "${RES_DETAILS[@]}" \
        "${RES_REMEDIATIONS[@]}"
    )

    local ret=$?
    if [[ $ret -ne 0 || -z "$sarif_json" ]]; then
        ui_error "Failed to generate SARIF report."
        return 1
    fi

    if [[ -n "$output_file" && "$output_file" != "-" ]]; then
        local out_dir="${output_file:h}"
        [[ -d "$out_dir" ]] || mkdir -p "$out_dir"
        printf "%s\n" "$sarif_json" > "$output_file"

        # Validate strictly with python3 -m json.tool
        if python3 -m json.tool "$output_file" >/dev/null 2>&1; then
            if [[ "${MACHAR_QUIET:-0}" -eq 0 ]]; then
                ui_success "OASIS SARIF v2.1.0 report generated: ${output_file}"
            fi
            return 0
        else
            ui_error "SARIF report at '${output_file}' failed JSON validation."
            return 1
        fi
    else
        printf "%s\n" "$sarif_json"
        return 0
    fi
}
