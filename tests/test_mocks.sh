#!/bin/zsh
# ==============================================================================
# macharden - tests/test_mocks.sh
# Unit tests for audit check logic using mocked system utilities
# ==============================================================================

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Setup isolated sandbox for mock binaries
MOCK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/machar_mocks.XXXXXX")
MOCK_BIN="${MOCK_DIR}/bin"
mkdir -p "$MOCK_BIN"

cleanup() {
    rm -rf "$MOCK_DIR"
}
trap cleanup EXIT

# Test counters
TOTAL_MOCK_TESTS=0
PASSED_MOCK_TESTS=0
FAILED_MOCK_TESTS=0

log_mock_test() {
    local test_status="$1"
    local desc="$2"
    local detail="${3:-}"
    if [[ "$test_status" == "PASS" ]]; then
        printf "  \033[92m✔ PASS\033[0m: %s\n" "$desc"
        (( ++PASSED_MOCK_TESTS ))
    else
        printf "  \033[91m✖ FAIL\033[0m: %s\n" "$desc"
        [[ -n "$detail" ]] && printf "         \033[2m%s\033[0m\n" "$detail"
        (( ++FAILED_MOCK_TESTS ))
    fi
    (( ++TOTAL_MOCK_TESTS ))
}

assert_mock_status() {
    local expected="$1"
    local actual="$2"
    local desc="$3"
    if [[ "$expected" == "$actual" ]]; then
        log_mock_test "PASS" "$desc"
    else
        log_mock_test "FAIL" "$desc" "Expected: '$expected', Got: '$actual'"
    fi
}

echo ""
echo "\033[1m\033[96m======================================================================\033[0m"
echo "           \033[1mmacharden Mocked System Audit Logic Tests\033[0m"
echo "\033[1m\033[96m======================================================================\033[0m"

# Export isolated PATH with mock binaries first
export PATH="${MOCK_BIN}:${PATH}"

# Source required modules
source "${PROJECT_ROOT}/lib/ui.sh"
ui_disable_colors
source "${PROJECT_ROOT}/lib/engine.sh"
source "${PROJECT_ROOT}/lib/audit_hardening.sh"
source "${PROJECT_ROOT}/lib/audit_network.sh"

# ==============================================================================
# Test 1: SIP Audit Mock (csrutil)
# ==============================================================================
echo "\n\033[1m[Mock Test 1] System Integrity Protection (audit_sip)\033[0m"

# Mock csrutil enabled
cat << 'EOF' > "${MOCK_BIN}/csrutil"
#!/bin/sh
echo "System Integrity Protection status: enabled."
exit 0
EOF
chmod +x "${MOCK_BIN}/csrutil"

RES_STATUSES=()
audit_sip "HARD-01" "hardening" "SIP" 10
assert_mock_status "PASS" "${RES_STATUSES[-1]:-}" "audit_sip reports PASS when csrutil reports enabled"

# Mock csrutil disabled
cat << 'EOF' > "${MOCK_BIN}/csrutil"
#!/bin/sh
echo "System Integrity Protection status: disabled."
exit 0
EOF
chmod +x "${MOCK_BIN}/csrutil"

RES_STATUSES=()
audit_sip "HARD-01" "hardening" "SIP" 10
assert_mock_status "FAIL" "${RES_STATUSES[-1]:-}" "audit_sip reports FAIL when csrutil reports disabled"

# ==============================================================================
# Test 2: FileVault Audit Mock (fdesetup)
# ==============================================================================
echo "\n\033[1m[Mock Test 2] FileVault Disk Encryption (audit_filevault)\033[0m"

# Mock fdesetup on
cat << 'EOF' > "${MOCK_BIN}/fdesetup"
#!/bin/sh
echo "FileVault is On."
exit 0
EOF
chmod +x "${MOCK_BIN}/fdesetup"

RES_STATUSES=()
audit_filevault "HARD-02" "hardening" "FileVault" 10
assert_mock_status "PASS" "${RES_STATUSES[-1]:-}" "audit_filevault reports PASS when FileVault is On"

# Mock fdesetup off
cat << 'EOF' > "${MOCK_BIN}/fdesetup"
#!/bin/sh
echo "FileVault is Off."
exit 0
EOF
chmod +x "${MOCK_BIN}/fdesetup"

RES_STATUSES=()
audit_filevault "HARD-02" "hardening" "FileVault" 10
assert_mock_status "FAIL" "${RES_STATUSES[-1]:-}" "audit_filevault reports FAIL when FileVault is Off"

# ==============================================================================
# Test 3: Gatekeeper Audit Mock (spctl)
# ==============================================================================
echo "\n\033[1m[Mock Test 3] Gatekeeper Assessment (audit_gatekeeper)\033[0m"

# Mock spctl assessments enabled
cat << 'EOF' > "${MOCK_BIN}/spctl"
#!/bin/sh
echo "assessments enabled"
exit 0
EOF
chmod +x "${MOCK_BIN}/spctl"

RES_STATUSES=()
audit_gatekeeper "HARD-03" "hardening" "Gatekeeper" 10
assert_mock_status "PASS" "${RES_STATUSES[-1]:-}" "audit_gatekeeper reports PASS when assessments enabled"

# Mock spctl assessments disabled
cat << 'EOF' > "${MOCK_BIN}/spctl"
#!/bin/sh
echo "assessments disabled"
exit 0
EOF
chmod +x "${MOCK_BIN}/spctl"

RES_STATUSES=()
audit_gatekeeper "HARD-03" "hardening" "Gatekeeper" 10
assert_mock_status "FAIL" "${RES_STATUSES[-1]:-}" "audit_gatekeeper reports FAIL when assessments disabled"

# ==============================================================================
# Test 4: IPv4 Forwarding Mock (sysctl)
# ==============================================================================
echo "\n\033[1m[Mock Test 4] IPv4 Forwarding (audit_ip_forwarding)\033[0m"

# Mock sysctl forwarding disabled (0)
cat << 'EOF' > "${MOCK_BIN}/sysctl"
#!/bin/sh
echo "0"
exit 0
EOF
chmod +x "${MOCK_BIN}/sysctl"

RES_STATUSES=()
audit_ip_forwarding "NET-05" "network" "IP Forwarding" 8
assert_mock_status "PASS" "${RES_STATUSES[-1]:-}" "audit_ip_forwarding reports PASS when sysctl is 0"

# Mock sysctl forwarding enabled (1)
cat << 'EOF' > "${MOCK_BIN}/sysctl"
#!/bin/sh
echo "1"
exit 0
EOF
chmod +x "${MOCK_BIN}/sysctl"

RES_STATUSES=()
audit_ip_forwarding "NET-05" "network" "IP Forwarding" 8
assert_mock_status "FAIL" "${RES_STATUSES[-1]:-}" "audit_ip_forwarding reports FAIL when sysctl is 1"

# ==============================================================================
# Summary
# ==============================================================================
echo ""
echo "\033[1m======================================================================\033[0m"
printf "\033[1mMock Test Results:\033[0m Total: %d | \033[92mPassed: %d\033[0m | \033[91mFailed: %d\033[0m\n" \
    "$TOTAL_MOCK_TESTS" "$PASSED_MOCK_TESTS" "$FAILED_MOCK_TESTS"
echo "\033[1m======================================================================\033[0m"

if (( FAILED_MOCK_TESTS > 0 )); then
    exit 1
else
    exit 0
fi
