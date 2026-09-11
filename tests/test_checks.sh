#!/bin/zsh
# ==============================================================================
# macharden - tests/test_checks.sh
# Unit tests for scoring formula, check registration, JSON/Markdown reporting,
# and remediation generator.
# ==============================================================================

set -u

# Resolve script directory and project root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Disable color in automated tests unless explicitly enabled
export MACHAR_NO_COLOR=1
export NO_COLOR=1
export MACHAR_QUIET=1

# Source core libraries
source "${PROJECT_ROOT}/lib/ui.sh"
source "${PROJECT_ROOT}/lib/engine.sh"
source "${PROJECT_ROOT}/lib/report.sh"
source "${PROJECT_ROOT}/lib/report_html.sh"
source "${PROJECT_ROOT}/lib/remediate.sh"
source "${PROJECT_ROOT}/lib/compliance.sh"

# Test state
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Temporary workspace for test outputs
TEST_TMP_DIR=$(mktemp -d -t macharden_test.XXXXXX)
trap 'rm -rf "${TEST_TMP_DIR}"' EXIT INT TERM

# Assertion helpers
log_test() {
    local test_status="$1"
    local name="$2"
    local details="${3:-}"
    if [[ "$test_status" == "PASS" ]]; then
        printf "  \033[92m✔ PASS\033[0m: %s\n" "$name"
        (( ++PASSED_TESTS ))
    else
        printf "  \033[91m✖ FAIL\033[0m: %s\n" "$name"
        [[ -n "$details" ]] && printf "         \033[90m%s\033[0m\n" "$details"
        (( ++FAILED_TESTS ))
    fi
    (( ++TOTAL_TESTS ))
}

assert_eq() {
    local expected="$1"
    local actual="$2"
    local desc="$3"
    if [[ "$expected" == "$actual" ]]; then
        log_test "PASS" "$desc"
    else
        log_test "FAIL" "$desc" "Expected: '$expected', Got: '$actual'"
    fi
}

assert_match() {
    local pattern="$1"
    local string="$2"
    local desc="$3"
    if echo "$string" | grep -Eq "$pattern"; then
        log_test "PASS" "$desc"
    else
        log_test "FAIL" "$desc" "String did not match pattern '$pattern'"
    fi
}

assert_file_exists() {
    local filepath="$1"
    local desc="$2"
    if [[ -f "$filepath" ]]; then
        log_test "PASS" "$desc"
    else
        log_test "FAIL" "$desc" "File not found: $filepath"
    fi
}

# Reset engine state between test suites
reset_engine() {
    REG_IDS=()
    REG_CATEGORIES=()
    REG_TITLES=()
    REG_WEIGHTS=()
    REG_FUNCS=()

    RES_IDS=()
    RES_CATEGORIES=()
    RES_TITLES=()
    RES_STATUSES=()
    RES_WEIGHTS=()
    RES_DETAILS=()
    RES_REMEDIATIONS=()

    HARDENING_INDEX=0.0
    TOTAL_POSSIBLE_POINTS=0.0
    EARNED_POINTS=0.0
    COUNT_PASS=0
    COUNT_WARN=0
    COUNT_FAIL=0
    COUNT_INFO=0
    COUNT_SUGG=0
    COUNT_TOTAL=0
    MACHAR_SKIP_IDS=()
}

echo ""
echo "\033[1m======================================================================\033[0m"
echo "\033[1m                RUNNING MACHARDEEN TEST SUITE                         \033[0m"
echo "\033[1m======================================================================\033[0m"

# ==============================================================================
# Suite 1: Scoring Formula & Normalization
# ==============================================================================
echo "\n\033[1m[Suite 1] Hardening Index Scoring Formula\033[0m"

# Test 1.1: 100% PASS
reset_engine
record_result "T-01" "hardening" "Check 1" "PASS" 10 "OK" ""
record_result "T-02" "hardening" "Check 2" "PASS" 10 "OK" ""
calculate_hardening_index
assert_eq "100.0" "$HARDENING_INDEX" "All PASS results in score 100.0%"
assert_eq "20.0" "$TOTAL_POSSIBLE_POINTS" "Total possible points sum correctly"
assert_eq "20.0" "$EARNED_POINTS" "Earned points equal total possible points on PASS"

# Test 1.2: 100% FAIL
reset_engine
record_result "T-01" "hardening" "Check 1" "FAIL" 10 "Failed" "fix1"
record_result "T-02" "hardening" "Check 2" "FAIL" 10 "Failed" "fix2"
calculate_hardening_index
assert_eq "0.0" "$HARDENING_INDEX" "All FAIL results in score 0.0%"
assert_eq "0.0" "$EARNED_POINTS" "Earned points equal 0.0 on 100% FAIL"

# Test 1.3: 100% WARN (50% weight earned)
reset_engine
record_result "T-01" "hardening" "Check 1" "WARN" 10 "Warning" "fix1"
record_result "T-02" "hardening" "Check 2" "WARN" 10 "Warning" "fix2"
calculate_hardening_index
assert_eq "50.0" "$HARDENING_INDEX" "All WARN results in score 50.0%"
assert_eq "10.0" "$EARNED_POINTS" "Earned points equal 50% of total points on WARN"

# Test 1.4: Mixed statuses with varying weights
# PASS wt 10 -> 10 pts
# WARN wt 10 -> 5 pts
# FAIL wt 10 -> 0 pts
# Total possible = 30, earned = 15 -> (15/30)*100 = 50.0%
reset_engine
record_result "T-01" "hardening" "PASS Check" "PASS" 10 "OK" ""
record_result "T-02" "hardening" "WARN Check" "WARN" 10 "WARN" "fix"
record_result "T-03" "hardening" "FAIL Check" "FAIL" 10 "FAIL" "fix"
calculate_hardening_index
assert_eq "50.0" "$HARDENING_INDEX" "Mixed PASS/WARN/FAIL yields normalized 50.0%"
assert_eq "30.0" "$TOTAL_POSSIBLE_POINTS" "Mixed total possible points = 30.0"
assert_eq "15.0" "$EARNED_POINTS" "Mixed earned points = 15.0"

# Test 1.5: INFO and SUGG are neutral (do not penalize score)
reset_engine
record_result "T-01" "hardening" "PASS Check" "PASS" 10 "OK" ""
record_result "T-02" "hardening" "INFO Check" "INFO" 10 "Informational" ""
record_result "T-03" "hardening" "SUGG Check" "SUGG" 10 "Suggestion" ""
calculate_hardening_index
assert_eq "100.0" "$HARDENING_INDEX" "INFO and SUGG do not penalize Hardening Index"
assert_eq "10.0" "$TOTAL_POSSIBLE_POINTS" "INFO/SUGG excluded from total possible points"

# Test 1.6: Empty check suite defaults to 100.0%
reset_engine
calculate_hardening_index
assert_eq "100.0" "$HARDENING_INDEX" "Empty check suite defaults to 100.0%"

# ==============================================================================
# Suite 2: Check Registration & Result Recording
# ==============================================================================
echo "\n\033[1m[Suite 2] Check Registration and Aliases\033[0m"

reset_engine
register_check "MOCK-01" "hardening" "Mock Check 1" 8 "mock_test_fn"
assert_eq "1" "${#REG_IDS[@]}" "register_check registers ID in array"
assert_eq "hardening" "${REG_CATEGORIES[1]}" "register_check registers category"
assert_eq "Mock Check 1" "${REG_TITLES[1]}" "register_check registers title"
assert_eq "8" "${REG_WEIGHTS[1]}" "register_check registers weight"
assert_eq "mock_test_fn" "${REG_FUNCS[1]}" "register_check registers function"

# Test status aliases normalization
record_result "MOCK-01" "hardening" "T1" "OK" 5 "ok" ""
record_result "MOCK-02" "hardening" "T2" "WARNING" 5 "warn" "fix"
record_result "MOCK-03" "hardening" "T3" "ERROR" 5 "err" "fix"
record_result "MOCK-04" "hardening" "T4" "RECOMMENDATION" 5 "sugg" ""
record_result "MOCK-05" "hardening" "T5" "INFORMATIONAL" 5 "info" ""

assert_eq "PASS" "${RES_STATUSES[1]}" "Alias 'OK' normalizes to 'PASS'"
assert_eq "WARN" "${RES_STATUSES[2]}" "Alias 'WARNING' normalizes to 'WARN'"
assert_eq "FAIL" "${RES_STATUSES[3]}" "Alias 'ERROR' normalizes to 'FAIL'"
assert_eq "SUGG" "${RES_STATUSES[4]}" "Alias 'RECOMMENDATION' normalizes to 'SUGG'"
assert_eq "INFO" "${RES_STATUSES[5]}" "Alias 'INFORMATIONAL' normalizes to 'INFO'"

assert_eq "1" "$COUNT_PASS" "COUNT_PASS increments properly"
assert_eq "1" "$COUNT_WARN" "COUNT_WARN increments properly"
assert_eq "1" "$COUNT_FAIL" "COUNT_FAIL increments properly"
assert_eq "1" "$COUNT_SUGG" "COUNT_SUGG increments properly"
assert_eq "1" "$COUNT_INFO" "COUNT_INFO increments properly"
assert_eq "5" "$COUNT_TOTAL" "COUNT_TOTAL equals 5"

# Test execution via run_audit with category filter
reset_engine
mock_audit_hard() {
    record_result "$1" "$2" "$3" "PASS" "$4" "Passed mock hardening" ""
}
mock_audit_net() {
    record_result "$1" "$2" "$3" "WARN" "$4" "Mock network warning" "fix_net"
}
register_check "H-01" "hardening" "Hardening check" 10 "mock_audit_hard"
register_check "N-01" "network" "Network check" 10 "mock_audit_net"

# Run category filter "hardening"
run_audit "hardening"
assert_eq "1" "$COUNT_TOTAL" "Category filtering runs only targeted checks"
assert_eq "H-01" "${RES_IDS[1]}" "Targeted check ID recorded"

# Run all
run_audit "all"
assert_eq "2" "$COUNT_TOTAL" "run_audit 'all' executes all registered checks"

# ==============================================================================
# Suite 3: Remediation Script Generator
# ==============================================================================
echo "\n\033[1m[Suite 3] Remediation Script Generation\033[0m"

reset_engine
record_result "FIX-01" "hardening" "FileVault Disabled" "FAIL" 10 "FileVault is off" "echo 'enabling filevault'"
record_result "FIX-02" "network" "Stealth Mode Off" "WARN" 5 "Stealth mode disabled" "echo 'enabling stealth mode'"
record_result "FIX-03" "hardening" "SIP Active" "PASS" 10 "SIP is enabled" ""

FIX_SCRIPT="${TEST_TMP_DIR}/fix_hardening.sh"
generate_fix_script "$FIX_SCRIPT"

assert_file_exists "$FIX_SCRIPT" "Fix script file was generated"

# Verify executable bit
if [[ -x "$FIX_SCRIPT" ]]; then
    log_test "PASS" "Fix script has executable permission (chmod +x)"
else
    log_test "FAIL" "Fix script does NOT have executable permission"
fi

# Verify script syntax with bash -n and zsh -n
if bash -n "$FIX_SCRIPT" 2>/dev/null; then
    log_test "PASS" "Generated fix script passes 'bash -n' syntax check"
else
    log_test "FAIL" "Generated fix script failed 'bash -n' syntax check"
fi

if zsh -n "$FIX_SCRIPT" 2>/dev/null; then
    log_test "PASS" "Generated fix script passes 'zsh -n' syntax check"
else
    log_test "FAIL" "Generated fix script failed 'zsh -n' syntax check"
fi

# Verify script content contains commands
FIX_CONTENT=$(cat "$FIX_SCRIPT")
assert_match "enabling filevault" "$FIX_CONTENT" "Fix script contains FAIL check remediation command"
assert_match "enabling stealth mode" "$FIX_CONTENT" "Fix script contains WARN check remediation command"

# Verify that PASS check is NOT in the fix commands
if echo "$FIX_CONTENT" | grep -q "FIX-03"; then
    log_test "FAIL" "PASS check should not be included in fix script"
else
    log_test "PASS" "PASS check is excluded from fix script"
fi

# ==============================================================================
# Suite 4: JSON Report Generation and Schema Validity
# ==============================================================================
echo "\n\033[1m[Suite 4] JSON Report Generation & Schema Validation\033[0m"

JSON_FILE="${TEST_TMP_DIR}/report.json"
calculate_hardening_index
report_json "$JSON_FILE"

assert_file_exists "$JSON_FILE" "JSON report was generated"

# Validate valid JSON using python3 -m json.tool
if python3 -m json.tool "$JSON_FILE" >/dev/null 2>&1; then
    log_test "PASS" "JSON report is 100% valid according to 'python3 -m json.tool'"
else
    log_test "FAIL" "JSON report failed syntax validation with python3 -m json.tool"
fi

# Validate JSON content schema via python3
VALIDATION_SCRIPT="
import json, sys
data = json.load(open(sys.argv[1]))
assert 'scanner' in data, 'Missing scanner object'
assert data['scanner']['name'] == 'macharden', 'Scanner name mismatch'
assert 'system' in data, 'Missing system object'
assert 'summary' in data, 'Missing summary object'
assert 'checks' in data, 'Missing checks array'
assert isinstance(data['checks'], list), 'checks must be a list'
assert len(data['checks']) == 3, f'Expected 3 checks, got {len(data[\"checks\"])}'
assert 'hardening_index' in data['summary'], 'Missing hardening_index'
print('OK')
"
JSON_VALID_OUT=$(python3 -c "$VALIDATION_SCRIPT" "$JSON_FILE" 2>&1 || echo "ERROR")
assert_eq "OK" "$JSON_VALID_OUT" "JSON report adheres to full schema structure"

# ==============================================================================
# Suite 5: Markdown Report Generation
# ==============================================================================
echo "\n\033[1m[Suite 5] Markdown Report Formatting\033[0m"

MD_FILE="${TEST_TMP_DIR}/report.md"
report_markdown "$MD_FILE"

assert_file_exists "$MD_FILE" "Markdown report file was generated"

MD_CONTENT=$(cat "$MD_FILE")
assert_match "# macOS Security Hardening Audit Report" "$MD_CONTENT" "Markdown report contains title"
assert_match "## 2. Executive Summary" "$MD_CONTENT" "Markdown report contains Executive Summary"
assert_match "## 3. Comprehensive Audit Results" "$MD_CONTENT" "Markdown report contains Audit Results table"
assert_match "## 4. Remediation Playbook" "$MD_CONTENT" "Markdown report contains Remediation Playbook"
assert_match "enabling filevault" "$MD_CONTENT" "Markdown report contains remediation code block"
assert_match "Category Posture Breakdown" "$MD_CONTENT" "Markdown report contains Category Posture Breakdown table"
assert_match "Risk & Severity Distribution" "$MD_CONTENT" "Markdown report contains Risk & Severity Distribution table"
assert_match "Regulatory Framework Coverage" "$MD_CONTENT" "Markdown report contains Regulatory Framework Coverage summary"
assert_match "CIS Apple macOS Benchmark" "$MD_CONTENT" "Markdown report includes CIS framework coverage"
assert_match "NIST SP 800-53" "$MD_CONTENT" "Markdown report includes NIST framework coverage"
assert_match "MITRE ATT&CK" "$MD_CONTENT" "Markdown report includes MITRE framework coverage"

# Test Terminal UI functions & executive reporting
ROW_OUT=$(ui_category_score_row "Hardening" 85.0 12 1 1 2>&1)
assert_match "Hardening" "$ROW_OUT" "ui_category_score_row outputs category name"
assert_match "85.0%" "$ROW_OUT" "ui_category_score_row outputs score percentage"
assert_match "12 PASS" "$ROW_OUT" "ui_category_score_row outputs passed count"
assert_match "1 WARN" "$ROW_OUT" "ui_category_score_row outputs warn count"
assert_match "1 FAIL" "$ROW_OUT" "ui_category_score_row outputs fail count"

BOX_OUT=$(ui_grade_box 80.0 "B+" "GOOD / ACCEPTABLE" 2>&1)
assert_match "GRADE: B\+ \(80.0%\)" "$BOX_OUT" "ui_grade_box outputs letter grade and percentage"
assert_match "GOOD / ACCEPTABLE" "$BOX_OUT" "ui_grade_box outputs rating text"
assert_match "┌" "$BOX_OUT" "ui_grade_box renders top border"
assert_match "└" "$BOX_OUT" "ui_grade_box renders bottom border"

TERM_OUT=$(report_terminal 2>&1)
assert_match "Category Posture Breakdown:" "$TERM_OUT" "report_terminal contains Category Posture Breakdown"
assert_match "GRADE:" "$TERM_OUT" "report_terminal prominently displays grade box"
assert_match "Severity:" "$TERM_OUT" "report_terminal displays severity tags in remediation actions"


# ==============================================================================
# Suite 6: Shell Completions & Documentation Validation
# ==============================================================================
echo "\n\033[1m[Suite 6] Shell Completions & Documentation Validation\033[0m"

ZSH_COMP="${PROJECT_ROOT}/completions/macharden.zsh"
BASH_COMP="${PROJECT_ROOT}/completions/macharden.bash"
MAN_DOC="${PROJECT_ROOT}/docs/macharden.1"
MAKEFILE="${PROJECT_ROOT}/Makefile"

assert_file_exists "$ZSH_COMP" "Zsh completion script exists"
if zsh -n "$ZSH_COMP" 2>/dev/null; then
    log_test "PASS" "Zsh completion script passes 'zsh -n' syntax check"
else
    log_test "FAIL" "Zsh completion script failed 'zsh -n' syntax check"
fi

ZSH_COMP_CONTENT=$(cat "$ZSH_COMP")
assert_match "^#compdef macharden" "$ZSH_COMP_CONTENT" "Zsh completion script contains #compdef macharden tag"
assert_match "_arguments" "$ZSH_COMP_CONTENT" "Zsh completion uses _arguments mechanism"
assert_match "compliance" "$ZSH_COMP_CONTENT" "Zsh completion supports --compliance flag"

assert_file_exists "$BASH_COMP" "Bash completion script exists"
if bash -n "$BASH_COMP" 2>/dev/null; then
    log_test "PASS" "Bash completion script passes 'bash -n' syntax check"
else
    log_test "FAIL" "Bash completion script failed 'bash -n' syntax check"
fi

BASH_COMP_CONTENT=$(cat "$BASH_COMP")
assert_match "complete -F _macharden_completions macharden" "$BASH_COMP_CONTENT" "Bash completion registers complete -F _macharden_completions macharden"

# Test Bash completion functions directly
BASH_TEST_RES=$(bash -c "source '$BASH_COMP'; COMP_WORDS=(macharden -c ''); COMP_CWORD=2; _macharden_completions; echo \"\${COMPREPLY[*]}\"")
assert_match "hardening" "$BASH_TEST_RES" "Bash completion completes -c categories"
assert_match "persistence" "$BASH_TEST_RES" "Bash completion includes persistence category"

BASH_FORMAT_RES=$(bash -c "source '$BASH_COMP'; COMP_WORDS=(macharden -f ''); COMP_CWORD=2; _macharden_completions; echo \"\${COMPREPLY[*]}\"")
assert_match "json" "$BASH_FORMAT_RES" "Bash completion completes -f formats (json)"
assert_match "html" "$BASH_FORMAT_RES" "Bash completion completes -f formats (html)"

assert_file_exists "$MAN_DOC" "UNIX manual page (docs/macharden.1) exists"
MAN_CONTENT=$(cat "$MAN_DOC")
assert_match "^\.TH MACHARDEN 1" "$MAN_CONTENT" "Manual page contains valid .TH header macro"
assert_match "\.SH SYNOPSIS" "$MAN_CONTENT" "Manual page contains .SH SYNOPSIS section"
assert_match "\.SH OPTIONS" "$MAN_CONTENT" "Manual page contains .SH OPTIONS section"
assert_match "\.SH AUDIT CATEGORIES" "$MAN_CONTENT" "Manual page contains .SH AUDIT CATEGORIES section"
assert_match "\.SH SCORING ALGORITHM" "$MAN_CONTENT" "Manual page contains .SH SCORING ALGORITHM section"
assert_match "\.SH EXIT CODES" "$MAN_CONTENT" "Manual page contains .SH EXIT CODES section"

if command -v mandoc >/dev/null 2>&1; then
    MANDOC_ERR=$(mandoc -Tlint "$MAN_DOC" 2>&1)
    if [[ -z "$MANDOC_ERR" ]]; then
        log_test "PASS" "Manual page passes 'mandoc -Tlint' with zero warnings"
    else
        log_test "FAIL" "Manual page has mandoc lint warnings: $MANDOC_ERR"
    fi
fi

assert_file_exists "$MAKEFILE" "Makefile exists"
MAKE_CONTENT=$(cat "$MAKEFILE")
assert_match "install-completions:" "$MAKE_CONTENT" "Makefile defines install-completions target"
assert_match "install-man:" "$MAKE_CONTENT" "Makefile defines install-man target"

# ==============================================================================
# Suite 7: HTML Dashboard Report Generation & Zero-Dependency Validation
# ==============================================================================
echo "\n\033[1m[Suite 7] HTML Dashboard Report Generation & Interactive Feature Validation\033[0m"

reset_engine
record_result "HTML-01" "hardening" "Test Hardening Check" "PASS" 10 "All good" ""
record_result "HTML-02" "network" "Test Network Check" "WARN" 8 "Warning details" "sudo network_fix"
record_result "HTML-03" "secrets" "Test Secrets Check" "FAIL" 9 "Found secrets" "chmod 600 ~/.secret"
calculate_hardening_index

HTML_REPORT="${TEST_TMP_DIR}/test_report.html"
report_html "$HTML_REPORT"

assert_file_exists "$HTML_REPORT" "HTML report file was generated"

HTML_CONTENT=$(cat "$HTML_REPORT")
assert_match "<!DOCTYPE html>" "$HTML_CONTENT" "HTML contains <!DOCTYPE html> declaration"
assert_match "<html[^>]*lang=\"en\"" "$HTML_CONTENT" "HTML contains <html lang=\"en\"> tag"
assert_match "Hardening Score" "$HTML_CONTENT" "HTML contains Hardening Score section"
assert_match "gaugeRing" "$HTML_CONTENT" "HTML contains gaugeRing SVG element"
assert_match "System Metadata" "$HTML_CONTENT" "HTML contains System Metadata section"
assert_match "Target Hostname" "$HTML_CONTENT" "HTML contains Target Hostname field"
assert_match "Total Controls" "$HTML_CONTENT" "HTML contains Total Controls KPI counter"
assert_match "Passed" "$HTML_CONTENT" "HTML contains Passed checks counter"
assert_match "Warnings" "$HTML_CONTENT" "HTML contains Warnings checks counter"
assert_match "Failed" "$HTML_CONTENT" "HTML contains Failed checks counter"
assert_match "data-category=\"hardening\"" "$HTML_CONTENT" "HTML contains Hardening category tab"
assert_match "data-category=\"network\"" "$HTML_CONTENT" "HTML contains Network category tab"
assert_match "data-category=\"secrets\"" "$HTML_CONTENT" "HTML contains Secrets category tab"
assert_match "data-category=\"persistence\"" "$HTML_CONTENT" "HTML contains Persistence category tab"
assert_match "data-status=\"all\"" "$HTML_CONTENT" "HTML contains All status filter"
assert_match "data-status=\"FAIL\"" "$HTML_CONTENT" "HTML contains Fail status filter"
assert_match "data-status=\"WARN\"" "$HTML_CONTENT" "HTML contains Warn status filter"
assert_match "data-status=\"PASS\"" "$HTML_CONTENT" "HTML contains Pass status filter"
assert_match "id=\"searchInput\"" "$HTML_CONTENT" "HTML contains search input element"
assert_match "Copy Fix Command" "$HTML_CONTENT" "HTML contains Copy Fix Command button"
assert_match "@media print" "$HTML_CONTENT" "HTML contains @media print styling"

# Validate zero external links/scripts/stylesheets
EXTERNAL_LINKS=$(python3 -c "
import re
content = open('$HTML_REPORT').read()
links = re.findall(r'<(?:link|script|img)[^>]+(?:href|src)=[\"\x27](https?://[^\">>]+)[\"\x27]', content, re.I)
print(len(links))
")
assert_eq "0" "$EXTERNAL_LINKS" "HTML report has zero external CDN links or scripts"

# Verify CLI integration with -f html
CLI_HTML_REPORT="${TEST_TMP_DIR}/cli_format.html"
"${PROJECT_ROOT}/bin/macharden" -f html -o "$CLI_HTML_REPORT" >/dev/null 2>&1
assert_file_exists "$CLI_HTML_REPORT" "macharden -f html -o file generates HTML report"
CLI_HTML_CONTENT=$(cat "$CLI_HTML_REPORT")
assert_match "<!DOCTYPE html>" "$CLI_HTML_CONTENT" "CLI -f html output is valid HTML"

# Verify CLI auto-detection with -o *.html
CLI_AUTO_REPORT="${TEST_TMP_DIR}/cli_auto.html"
"${PROJECT_ROOT}/bin/macharden" -o "$CLI_AUTO_REPORT" >/dev/null 2>&1
assert_file_exists "$CLI_AUTO_REPORT" "macharden -o *.html auto-detects HTML and generates report"
CLI_AUTO_CONTENT=$(cat "$CLI_AUTO_REPORT")
assert_match "<!DOCTYPE html>" "$CLI_AUTO_CONTENT" "CLI auto-detected .html output is valid HTML"

# Compliance chips must resolve mappings (not fake 85% / empty CIS tags)
reset_engine
record_result "HARD-01" "hardening" "System Integrity Protection (SIP)" "PASS" 10 "SIP enabled" ""
calculate_hardening_index
CHIP_HTML="${TEST_TMP_DIR}/chip_report.html"
report_html "$CHIP_HTML"
CHIP_CONTENT=$(cat "$CHIP_HTML")
assert_match "CIS 5.1.2" "$CHIP_CONTENT" "HTML renders CIS chip from compliance mappings"
assert_match "SI-7" "$CHIP_CONTENT" "HTML renders NIST chip from compliance mappings"
assert_match "T1562.001" "$CHIP_CONTENT" "HTML renders MITRE chip from compliance mappings"
assert_match "v1.2.0" "$CHIP_CONTENT" "HTML navbar shows scanner version 1.2.0"

# ==============================================================================
# Suite 8: Continuous Background Monitoring & Daemon Management
# ==============================================================================
echo "\n\033[1m[Suite 8] Continuous Monitoring & Daemon Management\033[0m"

DAEMON_PLIST_TEMPLATE="${PROJECT_ROOT}/launchd/com.macharden.daemon.plist"
MONITOR_LIB="${PROJECT_ROOT}/lib/monitor.sh"

assert_file_exists "$DAEMON_PLIST_TEMPLATE" "LaunchAgent plist template exists"
if command -v plutil >/dev/null 2>&1; then
    if plutil -lint "$DAEMON_PLIST_TEMPLATE" >/dev/null 2>&1; then
        log_test "PASS" "LaunchAgent plist template passes 'plutil -lint' check"
    else
        log_test "FAIL" "LaunchAgent plist template failed 'plutil -lint'"
    fi
fi

assert_file_exists "$MONITOR_LIB" "Monitoring library lib/monitor.sh exists"
if zsh -n "$MONITOR_LIB" 2>/dev/null; then
    log_test "PASS" "Monitoring library passes 'zsh -n' syntax check"
else
    log_test "FAIL" "Monitoring library failed 'zsh -n' syntax check"
fi

# Source monitor library
source "$MONITOR_LIB"

if typeset -f daemon_install >/dev/null 2>&1; then
    log_test "PASS" "daemon_install function is defined"
else
    log_test "FAIL" "daemon_install function is missing"
fi

if typeset -f daemon_uninstall >/dev/null 2>&1; then
    log_test "PASS" "daemon_uninstall function is defined"
else
    log_test "FAIL" "daemon_uninstall function is missing"
fi

if typeset -f daemon_status >/dev/null 2>&1; then
    log_test "PASS" "daemon_status function is defined"
else
    log_test "FAIL" "daemon_status function is missing"
fi

if typeset -f send_alert >/dev/null 2>&1; then
    log_test "PASS" "send_alert function is defined"
else
    log_test "FAIL" "send_alert function is missing"
fi

# Isolated sandbox for testing daemon install / uninstall
SANDBOX_AGENTS="${TEST_TMP_DIR}/SandboxLaunchAgents"
SANDBOX_LOGS="${TEST_TMP_DIR}/SandboxLogs"
export MACHAR_LAUNCHAGENTS_DIR="$SANDBOX_AGENTS"
export MACHAR_LOG_DIR="$SANDBOX_LOGS"

# Test weekly install (default)
daemon_install "weekly" >/dev/null 2>&1
INSTALLED_PLIST="$SANDBOX_AGENTS/com.macharden.daemon.plist"
assert_file_exists "$INSTALLED_PLIST" "daemon_install creates LaunchAgent plist file"

PLIST_CONTENT=$(cat "$INSTALLED_PLIST" 2>/dev/null || echo "")
assert_match "com.macharden.daemon" "$PLIST_CONTENT" "Installed plist contains service label"
assert_match "604800" "$PLIST_CONTENT" "Weekly schedule configures StartInterval 604800"
assert_match "$SANDBOX_LOGS" "$PLIST_CONTENT" "Installed plist points to correct logs directory"

if command -v plutil >/dev/null 2>&1; then
    if plutil -lint "$INSTALLED_PLIST" >/dev/null 2>&1; then
        log_test "PASS" "Installed plist is 100% valid XML according to plutil"
    else
        log_test "FAIL" "Installed plist failed plutil validation"
    fi
fi

# Test daily install
daemon_install "daily" >/dev/null 2>&1
PLIST_CONTENT=$(cat "$INSTALLED_PLIST" 2>/dev/null || echo "")
assert_match "86400" "$PLIST_CONTENT" "Daily schedule configures StartInterval 86400"

# Test login schedule
daemon_install "login" >/dev/null 2>&1
PLIST_CONTENT=$(cat "$INSTALLED_PLIST" 2>/dev/null || echo "")
assert_match "<key>RunAtLoad</key>" "$PLIST_CONTENT" "Login schedule configures RunAtLoad"

# Test daemon_status in sandbox
STATUS_OUT=$(daemon_status 2>&1 || true)
assert_match "Installed" "$STATUS_OUT" "daemon_status detects installed plist in sandbox"
assert_match "com.macharden.daemon" "$STATUS_OUT" "daemon_status outputs service identifier"

# Test daemon_uninstall
daemon_uninstall >/dev/null 2>&1
if [[ ! -f "$INSTALLED_PLIST" ]]; then
    log_test "PASS" "daemon_uninstall removes LaunchAgent plist file"
else
    log_test "FAIL" "daemon_uninstall failed to remove LaunchAgent plist file"
fi

# Test invalid schedule error handling
if daemon_install "invalid_sched" >/dev/null 2>&1; then
    log_test "FAIL" "daemon_install should reject invalid schedule"
else
    log_test "PASS" "daemon_install rejects invalid schedule"
fi

# Test send_alert behavior
ALERT_CLEAN_OUT=$(send_alert 100.0 0 2>&1)
assert_match "suppressed" "$ALERT_CLEAN_OUT" "send_alert suppresses notification when audit is 100% clean"

ALERT_FAIL_OUT=$(send_alert 60.0 3 2>&1)
assert_match "alert" "$ALERT_FAIL_OUT" "send_alert triggers notification when failures > 0"

ALERT_LOW_OUT=$(send_alert 65.0 0 2>&1)
assert_match "threshold" "$ALERT_LOW_OUT" "send_alert notifies when score is below 70 with zero failures"

# Test CLI integration with --daemon-status
CLI_STATUS_OUT=$("${PROJECT_ROOT}/bin/macharden" --daemon-status 2>&1 || true)
assert_match "macharden Background Daemon Status" "$CLI_STATUS_OUT" "CLI --daemon-status executes daemon_status"

# Test CLI integration with --daemon-install in sandbox
"${PROJECT_ROOT}/bin/macharden" --daemon-install daily >/dev/null 2>&1
assert_file_exists "$INSTALLED_PLIST" "CLI --daemon-install daily installs LaunchAgent"
"${PROJECT_ROOT}/bin/macharden" --daemon-uninstall >/dev/null 2>&1

unset MACHAR_LAUNCHAGENTS_DIR
unset MACHAR_LOG_DIR

# ==============================================================================
# Suite 9: Compliance & Security Framework Mapper (CIS, NIST, MITRE)
# ==============================================================================
echo "\n\033[1m[Suite 9] Compliance & Security Framework Mapper\033[0m"

COMPLIANCE_FILE="${PROJECT_ROOT}/data/compliance_mappings.json"
assert_file_exists "$COMPLIANCE_FILE" "Compliance mapping data/compliance_mappings.json exists"

if python3 -m json.tool "$COMPLIANCE_FILE" >/dev/null 2>&1; then
    log_test "PASS" "compliance_mappings.json is 100% valid JSON"
else
    log_test "FAIL" "compliance_mappings.json failed JSON syntax validation"
fi

# Verify mappings schema and coverage for core checks
SCHEMA_CHECK_SCRIPT="import json, sys
data = json.load(open(sys.argv[1]))
assert 'mappings' in data, 'Missing mappings object'
mappings = data['mappings']
required_checks = [\"HARD-01\", \"HARD-02\", \"HARD-08\", \"HARD-12\", \"HARD-14\", \"NET-01\", \"NET-10\", \"SEC-01\", \"SEC-08\", \"SEC-09\", \"PERS-01\", \"PERS-08\"]
for cid in required_checks:
    assert cid in mappings, f'Missing check {cid}'
    entry = mappings[cid]
    assert 'cis' in entry and 'id' in entry['cis'], f'Missing CIS in {cid}'
    assert 'nist' in entry and 'controls' in entry['nist'], f'Missing NIST in {cid}'
    assert 'mitre' in entry and ('primary_technique' in entry['mitre'] or 'techniques' in entry['mitre']), f'Missing MITRE in {cid}'
sys.exit(0)
"
if python3 -c "$SCHEMA_CHECK_SCRIPT" "$COMPLIANCE_FILE" >/dev/null 2>&1; then
    log_test "PASS" "compliance_mappings.json contains all required frameworks and controls"
else
    log_test "FAIL" "compliance_mappings.json schema validation failed"
fi

# Function existence checks
if typeset -f get_compliance_tags >/dev/null 2>&1; then
    log_test "PASS" "get_compliance_tags function is defined"
else
    log_test "FAIL" "get_compliance_tags function is missing"
fi

if typeset -f calculate_compliance_metrics >/dev/null 2>&1; then
    log_test "PASS" "calculate_compliance_metrics function is defined"
else
    log_test "FAIL" "calculate_compliance_metrics function is missing"
fi

if typeset -f report_compliance_summary >/dev/null 2>&1; then
    log_test "PASS" "report_compliance_summary function is defined"
else
    log_test "FAIL" "report_compliance_summary function is missing"
fi

if typeset -f report_compliance_cis >/dev/null 2>&1; then
    log_test "PASS" "report_compliance_cis function is defined"
else
    log_test "FAIL" "report_compliance_cis function is missing"
fi

if typeset -f report_compliance_nist >/dev/null 2>&1; then
    log_test "PASS" "report_compliance_nist function is defined"
else
    log_test "FAIL" "report_compliance_nist function is missing"
fi

if typeset -f report_compliance_mitre >/dev/null 2>&1; then
    log_test "PASS" "report_compliance_mitre function is defined"
else
    log_test "FAIL" "report_compliance_mitre function is missing"
fi

if typeset -f report_compliance_framework >/dev/null 2>&1; then
    log_test "PASS" "report_compliance_framework function is defined"
else
    log_test "FAIL" "report_compliance_framework function is missing"
fi

# Tag retrieval tests
TAGS_ALL=$(get_compliance_tags "HARD-01" 2>&1 || true)
assert_match "CIS: 5.1.2" "$TAGS_ALL" "get_compliance_tags 'all' includes CIS tag"
assert_match "NIST:" "$TAGS_ALL" "get_compliance_tags 'all' includes NIST tag"
assert_match "MITRE:" "$TAGS_ALL" "get_compliance_tags 'all' includes MITRE tag"

TAGS_CIS=$(get_compliance_tags "HARD-01" "cis" 2>&1 || true)
assert_match "5.1.2" "$TAGS_CIS" "get_compliance_tags 'cis' returns CIS identifier"

TAGS_NIST=$(get_compliance_tags "HARD-01" "nist" 2>&1 || true)
assert_match "SI-7" "$TAGS_NIST" "get_compliance_tags 'nist' returns NIST controls"

TAGS_MITRE=$(get_compliance_tags "HARD-01" "mitre" 2>&1 || true)
assert_match "T1562.001" "$TAGS_MITRE" "get_compliance_tags 'mitre' returns MITRE technique"

TAGS_JSON=$(get_compliance_tags "HARD-01" "json" 2>&1 || true)
if echo "$TAGS_JSON" | python3 -m json.tool >/dev/null 2>&1; then
    log_test "PASS" "get_compliance_tags 'json' returns valid JSON"
else
    log_test "FAIL" "get_compliance_tags 'json' returned invalid JSON"
fi

TAGS_UNKNOWN=$(get_compliance_tags "UNKNOWN-999" 2>&1 || true)
assert_match "N/A" "$TAGS_UNKNOWN" "get_compliance_tags handles unknown check ID gracefully"

# Framework metrics and scoring calculation tests
reset_engine
record_result "HARD-01" "hardening" "SIP Status" "PASS" 10 "SIP is enabled" ""
record_result "HARD-02" "hardening" "FileVault Encryption" "FAIL" 10 "FileVault disabled" "fdesetup enable"
record_result "NET-04" "network" "Remote Login (SSH)" "WARN" 5 "SSH is enabled" "systemsetup -setremotelogin off"
record_result "PERS-06" "persistence" "Login Items Count" "INFO" 2 "Found 3 login items" ""

calculate_compliance_metrics
assert_eq "50.0" "$CIS_COMPLIANCE_PCT" "calculate_compliance_metrics calculates weighted CIS percentage"
assert_eq "50.0" "$NIST_COMPLIANCE_PCT" "calculate_compliance_metrics calculates weighted NIST percentage"
assert_eq "3" "$CIS_TOTAL_COUNT" "calculate_compliance_metrics excludes neutral INFO from CIS count"
assert_eq "1" "$CIS_PASS_COUNT" "CIS_PASS_COUNT matches expected value"
assert_eq "1" "$CIS_WARN_COUNT" "CIS_WARN_COUNT matches expected value"
assert_eq "1" "$CIS_FAIL_COUNT" "CIS_FAIL_COUNT matches expected value"

# Terminal Summary Report
COMP_TERM_OUT=$(report_compliance_summary "term" 2>&1 || true)
assert_match "ENTERPRISE COMPLIANCE POSTURE SUMMARY" "$COMP_TERM_OUT" "report_compliance_summary terminal output contains header"
assert_match "CIS Apple macOS Benchmark" "$COMP_TERM_OUT" "report_compliance_summary terminal output includes CIS"
assert_match "NIST SP 800-53" "$COMP_TERM_OUT" "report_compliance_summary terminal output includes NIST"
assert_match "MITRE ATT&CK Defense Coverage" "$COMP_TERM_OUT" "report_compliance_summary terminal output includes MITRE"

# Markdown Summary Report
COMP_MD_FILE="${TEST_TMP_DIR}/compliance_summary.md"
report_compliance_summary "markdown" "$COMP_MD_FILE" >/dev/null 2>&1
assert_file_exists "$COMP_MD_FILE" "report_compliance_summary markdown file was created"
COMP_MD_CONTENT=$(cat "$COMP_MD_FILE" 2>/dev/null || echo "")
assert_match "Compliance Score" "$COMP_MD_CONTENT" "Compliance markdown report contains Compliance Score header"
assert_match "CIS Apple macOS Benchmark" "$COMP_MD_CONTENT" "Compliance markdown report contains CIS entry"

# JSON Summary Report
COMP_JSON_FILE="${TEST_TMP_DIR}/compliance_summary.json"
report_compliance_summary "json" "$COMP_JSON_FILE" >/dev/null 2>&1
assert_file_exists "$COMP_JSON_FILE" "report_compliance_summary JSON file was created"
if python3 -m json.tool "$COMP_JSON_FILE" >/dev/null 2>&1; then
    log_test "PASS" "report_compliance_summary JSON file is valid JSON"
else
    log_test "FAIL" "report_compliance_summary JSON file failed JSON validation"
fi

# Framework specific reports
CIS_TERM_OUT=$(report_compliance_cis "term" 2>&1 || true)
assert_match "CIS APPLE macOS BENCHMARK" "$CIS_TERM_OUT" "report_compliance_cis terminal report outputs header"

NIST_TERM_OUT=$(report_compliance_nist "term" 2>&1 || true)
assert_match "NIST SP 800-53" "$NIST_TERM_OUT" "report_compliance_nist terminal report outputs header"

MITRE_TERM_OUT=$(report_compliance_mitre "term" 2>&1 || true)
assert_match "MITRE ATT&CK MATRIX FOR macOS" "$MITRE_TERM_OUT" "report_compliance_mitre terminal report outputs header"

# Test CLI --compliance integration
CLI_CIS_OUT=$("${PROJECT_ROOT}/bin/macharden" -c hardening -q --compliance cis 2>&1 || true)
assert_match "CIS APPLE macOS BENCHMARK" "$CLI_CIS_OUT" "CLI --compliance cis outputs CIS benchmark posture"

CLI_NIST_OUT=$("${PROJECT_ROOT}/bin/macharden" -c hardening -q --compliance nist 2>&1 || true)
assert_match "NIST SP 800-53" "$CLI_NIST_OUT" "CLI --compliance nist outputs NIST 800-53 posture"

CLI_MITRE_OUT=$("${PROJECT_ROOT}/bin/macharden" -c hardening -q --compliance mitre 2>&1 || true)
assert_match "MITRE ATT&CK MATRIX FOR macOS" "$CLI_MITRE_OUT" "CLI --compliance mitre outputs MITRE ATT&CK posture"

CLI_ALL_OUT=$("${PROJECT_ROOT}/bin/macharden" -c hardening -q --compliance all 2>&1 || true)
assert_match "ENTERPRISE COMPLIANCE POSTURE SUMMARY" "$CLI_ALL_OUT" "CLI --compliance all outputs regulatory overview"

CLI_JSON_OUT="${TEST_TMP_DIR}/cli_compliance_out.json"
"${PROJECT_ROOT}/bin/macharden" -c hardening -q -f json --compliance all -o "$CLI_JSON_OUT" >/dev/null 2>&1
assert_file_exists "$CLI_JSON_OUT" "CLI --compliance all -f json generates output file"
if python3 -m json.tool "$CLI_JSON_OUT" >/dev/null 2>&1; then
    log_test "PASS" "CLI --compliance all -f json produces valid JSON"
else
    log_test "FAIL" "CLI --compliance all -f json produced invalid JSON"
fi


# ==============================================================================
# Suite 10: v1.1 Check Registry, CLI Validation, and Version
# ==============================================================================
echo "\n\033[1m[Suite 10] Check Registry, CLI Validation, and Version\033[0m"

reset_engine
source "${PROJECT_ROOT}/lib/audit_hardening.sh"
source "${PROJECT_ROOT}/lib/audit_network.sh"
source "${PROJECT_ROOT}/lib/audit_secrets.sh"
source "${PROJECT_ROOT}/lib/audit_persistence.sh"

assert_eq "44" "${#REG_IDS[@]}" "v1.2 registers 44 audit checks"

for expected_id in HARD-08 HARD-09 HARD-10 HARD-11 HARD-12 HARD-13 HARD-14 HARD-15 NET-07 NET-08 NET-09 NET-10 NET-11 SEC-06 SEC-07 SEC-08 SEC-09 PERS-07 PERS-08 PERS-09; do
    found_id=0
    for (( i = 1; i <= ${#REG_IDS[@]}; i++ )); do
        if [[ "${REG_IDS[i]}" == "$expected_id" ]]; then
            found_id=1
            break
        fi
    done
    if (( found_id )); then
        log_test "PASS" "Registry includes ${expected_id}"
    else
        log_test "FAIL" "Registry includes ${expected_id}" "ID not found in REG_IDS"
    fi
done

if typeset -f audit_firmware_password >/dev/null 2>&1 \
    && typeset -f audit_secure_boot >/dev/null 2>&1 \
    && typeset -f audit_autologin >/dev/null 2>&1 \
    && typeset -f audit_bluetooth_sharing >/dev/null 2>&1 \
    && typeset -f audit_airdrop >/dev/null 2>&1 \
    && typeset -f audit_internet_sharing >/dev/null 2>&1 \
    && typeset -f audit_firewall_logging >/dev/null 2>&1 \
    && typeset -f audit_unencrypted_ssh_keys >/dev/null 2>&1 \
    && typeset -f audit_shell_history_secrets >/dev/null 2>&1 \
    && typeset -f audit_privileged_helpers >/dev/null 2>&1 \
    && typeset -f audit_home_permissions >/dev/null 2>&1 \
    && typeset -f audit_network_time >/dev/null 2>&1 \
    && typeset -f audit_malware_protection >/dev/null 2>&1 \
    && typeset -f audit_ip_forwarding >/dev/null 2>&1 \
    && typeset -f audit_promiscuous_interfaces >/dev/null 2>&1 \
    && typeset -f audit_sshd_hardening >/dev/null 2>&1 \
    && typeset -f audit_suspicious_history_files >/dev/null 2>&1 \
    && typeset -f audit_printer_sharing >/dev/null 2>&1 \
    && typeset -f audit_usb_restricted_mode >/dev/null 2>&1 \
    && typeset -f audit_sudo_timestamp >/dev/null 2>&1; then
    log_test "PASS" "All v1.2 audit functions are defined"
else
    log_test "FAIL" "All v1.2 audit functions are defined"
fi

VERSION_OUT=$("${PROJECT_ROOT}/bin/macharden" --version 2>&1)
assert_match "1.2.0" "$VERSION_OUT" "macharden --version reports 1.2.0"

INVALID_CAT_OUT=$("${PROJECT_ROOT}/bin/macharden" -c bogus 2>&1) || true
INVALID_CAT_EC=0
"${PROJECT_ROOT}/bin/macharden" -c bogus >/dev/null 2>&1 || INVALID_CAT_EC=$?
assert_eq "1" "$INVALID_CAT_EC" "Invalid -c category exits 1"
assert_match "Invalid category" "$INVALID_CAT_OUT" "Invalid -c category prints error"

HELP_OUT=$("${PROJECT_ROOT}/bin/macharden" --help 2>&1)
assert_match "html" "$HELP_OUT" "Help lists html report format"
assert_match "daemon-install" "$HELP_OUT" "Help lists --daemon-install"
assert_match "compliance" "$HELP_OUT" "Help lists --compliance"
assert_match "skip-test" "$HELP_OUT" "Help lists --skip-test"
assert_match "profile" "$HELP_OUT" "Help lists --profile"

# Skip-test engine + profile file
reset_engine
mock_keep() { record_result "$1" "$2" "$3" "PASS" "$4" "would pass" ""; }
mock_skip() { record_result "$1" "$2" "$3" "FAIL" "$4" "should not run" "echo y"; }
register_check "KEEP-01" "hardening" "Keep me" 10 "mock_keep"
register_check "SKIP-01" "hardening" "Skip me" 10 "mock_skip"
add_skip_test "SKIP-01"
run_audit "all"
assert_eq "2" "$COUNT_TOTAL" "skip-test still records a result for skipped IDs"
assert_eq "INFO" "${RES_STATUSES[2]}" "Skipped check records INFO (neutral)"
assert_eq "PASS" "${RES_STATUSES[1]}" "Non-skipped check still executes"
assert_eq "100.0" "$HARDENING_INDEX" "Skipped check does not penalize Hardening Index"
assert_eq "10.0" "$TOTAL_POSSIBLE_POINTS" "Skipped check is excluded from the Hardening Index denominator"

SKIP_PRF="${TEST_TMP_DIR}/macharden.prf"
printf '# comment\nskip-test=HARD-99\nskip-test=NET-01,SEC-02\n' > "$SKIP_PRF"
reset_engine
MACHAR_SKIP_IDS=()
load_skip_profile "$SKIP_PRF"
if is_skipped "HARD-99" && is_skipped "NET-01" && is_skipped "SEC-02"; then
    log_test "PASS" "load_skip_profile parses skip-test lines and comma lists"
else
    log_test "FAIL" "load_skip_profile parses skip-test lines and comma lists"
fi

CLI_SKIP_OUT=$("${PROJECT_ROOT}/bin/macharden" --skip-test HARD-08 -c hardening -q -f json -o "${TEST_TMP_DIR}/skip.json" 2>&1) || true
if python3 - "$TEST_TMP_DIR/skip.json" << 'PY'
import json, sys
data=json.load(open(sys.argv[1]))
hits=[c for c in data.get("checks", []) if c.get("id")=="HARD-08"]
assert hits, "HARD-08 missing"
assert hits[0]["status"]=="INFO"
assert "Skipped" in hits[0].get("details","")
PY
then
    log_test "PASS" "CLI --skip-test HARD-08 records INFO skipped in JSON"
else
    log_test "FAIL" "CLI --skip-test HARD-08 records INFO skipped in JSON"
fi

# ==============================================================================
# Final Test Summary
# ==============================================================================
echo ""
echo "\033[1m======================================================================\033[0m"
printf "\033[1mTest Results:\033[0m Total: %d | \033[92mPassed: %d\033[0m | \033[91mFailed: %d\033[0m\n" \
    "$TOTAL_TESTS" "$PASSED_TESTS" "$FAILED_TESTS"
echo "\033[1m======================================================================\033[0m"

if (( FAILED_TESTS > 0 )); then
    echo "\033[91m✖ Some unit tests failed!\033[0m"
    exit 1
else
    echo "\033[92m✔ All unit tests passed successfully!\033[0m"
    exit 0
fi
