#!/bin/zsh
# ==============================================================================
# macharden - tests/test_scenarios.sh
# Evidence scenarios: every check runs in a sandbox that only holds the evidence the scenario
# provides (docs/ARCHITECTURE.md, "Check contract"). PASS requires evidence.
# ==============================================================================

set -u

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"

source "${PROJECT_ROOT}/lib/ui.sh"
ui_disable_colors
source "${PROJECT_ROOT}/lib/engine.sh"
for audit_file in "${PROJECT_ROOT}"/lib/audit_*.sh; do
    source "$audit_file"
done

source "${SCRIPT_DIR}/scenarios/lib.sh"

echo ""
echo "\033[1m\033[96m======================================================================\033[0m"
echo "           \033[1mmacharden Evidence Scenarios (PASS requires evidence)\033[0m"
echo "\033[1m\033[96m======================================================================\033[0m"

for scenario_file in selftest hardening network secrets persistence coverage; do
    [[ -f "${SCRIPT_DIR}/scenarios/${scenario_file}.sh" ]] && source "${SCRIPT_DIR}/scenarios/${scenario_file}.sh"
done

sc_summary
exit $?
