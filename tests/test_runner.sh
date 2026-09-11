#!/bin/zsh
# ==============================================================================
# macharden - tests/test_runner.sh
# Test runner for syntax validation (zsh -n, bash -n) and unit test execution
# ==============================================================================

set -u

# Resolve project root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Styling
C_RESET=$'\033[0m'
C_BOLD=$'\033[1m'
C_GREEN=$'\033[92m'
C_YELLOW=$'\033[93m'
C_RED=$'\033[91m'
C_CYAN=$'\033[96m'
C_DIM=$'\033[2m'

echo "${C_BOLD}${C_CYAN}======================================================================${C_RESET}"
echo "              ${C_BOLD}macharden Automated Test & Validation Runner${C_RESET}"
echo "${C_BOLD}${C_CYAN}======================================================================${C_RESET}"
echo "Root Directory : ${PROJECT_ROOT}"
echo "Timestamp      : $(date "+%Y-%m-%d %H:%M:%S %Z")"
echo "${C_DIM}----------------------------------------------------------------------${C_RESET}"

TOTAL_SYNTAX_CHECKS=0
PASSED_SYNTAX_CHECKS=0
FAILED_SYNTAX_CHECKS=0

# Collect all shell scripts in project
FILES_TO_CHECK=()

if [[ -f "${PROJECT_ROOT}/bin/macharden" ]]; then
    FILES_TO_CHECK+=("${PROJECT_ROOT}/bin/macharden")
fi

for f in "${PROJECT_ROOT}"/lib/*.sh; do
    [[ -f "$f" ]] && FILES_TO_CHECK+=("$f")
done

for f in "${PROJECT_ROOT}"/tests/*.sh; do
    [[ -f "$f" ]] && FILES_TO_CHECK+=("$f")
done

echo ""
echo "${C_BOLD}▶ Phase 1: Shell Syntax Verification (zsh -n & bash -n)${C_RESET}"
echo "${C_DIM}----------------------------------------------------------------------${C_RESET}"

for file in "${FILES_TO_CHECK[@]}"; do
    rel_path="${file#$PROJECT_ROOT/}"
    printf "  %-35s " "${rel_path}"

    # Check with zsh -n
    (( ++TOTAL_SYNTAX_CHECKS ))
    zsh_err=$(zsh -n "$file" 2>&1)
    zsh_exit=$?

    # Check with bash -n
    (( ++TOTAL_SYNTAX_CHECKS ))
    bash_err=$(bash -n "$file" 2>&1)
    bash_exit=$?

    if [[ $zsh_exit -eq 0 && $bash_exit -eq 0 ]]; then
        printf "[%b] zsh [%b] bash\n" "${C_GREEN}PASS${C_RESET}" "${C_GREEN}PASS${C_RESET}"
        (( PASSED_SYNTAX_CHECKS += 2 ))
    else
        printf "[%b] zsh [%b] bash\n" \
            "$([[ $zsh_exit -eq 0 ]] && echo "${C_GREEN}PASS${C_RESET}" || echo "${C_RED}FAIL${C_RESET}")" \
            "$([[ $bash_exit -eq 0 ]] && echo "${C_GREEN}PASS${C_RESET}" || echo "${C_RED}FAIL${C_RESET}")"

        if [[ $zsh_exit -ne 0 ]]; then
            echo "    ${C_RED}zsh error:${C_RESET} ${zsh_err}"
            (( ++FAILED_SYNTAX_CHECKS ))
        else
            (( ++PASSED_SYNTAX_CHECKS ))
        fi

        if [[ $bash_exit -ne 0 ]]; then
            echo "    ${C_RED}bash error:${C_RESET} ${bash_err}"
            (( ++FAILED_SYNTAX_CHECKS ))
        else
            (( ++PASSED_SYNTAX_CHECKS ))
        fi
    fi
done

echo ""
echo "${C_BOLD}▶ Phase 2: Unit & Engine Test Suite Execution${C_RESET}"
echo "${C_DIM}----------------------------------------------------------------------${C_RESET}"

TEST_CHECKS_SCRIPT="${PROJECT_ROOT}/tests/test_checks.sh"
UNIT_TESTS_EXIT=0

if [[ -f "$TEST_CHECKS_SCRIPT" ]]; then
    chmod +x "$TEST_CHECKS_SCRIPT"
    "$TEST_CHECKS_SCRIPT"
    UNIT_TESTS_EXIT=$?
else
    echo "${C_RED}Error: ${TEST_CHECKS_SCRIPT} not found!${C_RESET}"
    UNIT_TESTS_EXIT=1
fi

echo ""
echo "${C_BOLD}${C_CYAN}======================================================================${C_RESET}"
echo "                         ${C_BOLD}TEST RUN SUMMARY${C_RESET}"
echo "${C_BOLD}${C_CYAN}======================================================================${C_RESET}"
printf "  Syntax Checks : Total %d | %bPassed: %d%b | %bFailed: %d%b\n" \
    "$TOTAL_SYNTAX_CHECKS" "${C_GREEN}" "$PASSED_SYNTAX_CHECKS" "${C_RESET}" \
    "$([[ $FAILED_SYNTAX_CHECKS -gt 0 ]] && echo "${C_RED}" || echo "${C_GREEN}")" \
    "$FAILED_SYNTAX_CHECKS" "${C_RESET}"

printf "  Unit Tests    : %b\n" \
    "$([[ $UNIT_TESTS_EXIT -eq 0 ]] && echo "${C_GREEN}ALL TESTS PASSED${C_RESET}" || echo "${C_RED}TEST SUITE FAILED${C_RESET}")"
echo "${C_DIM}----------------------------------------------------------------------${C_RESET}"

if [[ $FAILED_SYNTAX_CHECKS -eq 0 && $UNIT_TESTS_EXIT -eq 0 ]]; then
    echo "${C_GREEN}${C_BOLD}✔ BUILD & TESTS SUCCEEDED - 0 ERRORS${C_RESET}"
    exit 0
else
    echo "${C_RED}${C_BOLD}✖ BUILD & TESTS FAILED${C_RESET}"
    exit 1
fi
