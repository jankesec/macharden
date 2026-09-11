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
source "${PROJECT_ROOT}/lib/remediate.sh"

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
