#!/bin/zsh
# Self-test of the scenario harness itself, using a fake check that is not registered.
echo "\n\033[1m[Scenarios] Harness self-test\033[0m"

# A fake check that needs a shimmed command, a file under the fake root and a file under HOME.
_zz_selftest_check() {
    local out
    if ! out=$(fakecmd --probe 2>/dev/null); then
        record_result "$1" "$2" "$3" "INFO" "$4" "fakecmd unavailable" ""
    elif [[ "$out" == "green" && -f "$(machar_path /etc/zz.conf)" && -f "$HOME/.zzrc" ]]; then
        record_result "$1" "$2" "$3" "PASS" "$4" "all evidence present" ""
    else
        record_result "$1" "$2" "$3" "WARN" "$4" "evidence incomplete: $out" ""
    fi
}

scenario_begin ZZ-01 "shim output, fake root and HOME reach the check" _zz_selftest_check
    shim fakecmd --when '--probe' --out green
    fs /etc/zz.conf 'x'
    home .zzrc 'x'
    expect PASS --details 'all evidence'
scenario_end

scenario_begin ZZ-01 "a command without a matching rule fails" _zz_selftest_check
    shim fakecmd --when '--other' --out green
    expect INFO --details 'unavailable'
scenario_end

scenario_begin ZZ-01 "a command that is not shimmed does not exist" _zz_selftest_check
    expect INFO
scenario_end

scenario_begin ZZ-01 "missing evidence downgrades the result" _zz_selftest_check
    shim fakecmd --when '--probe' --out green
    expect WARN --details 'incomplete'
scenario_end

# The sandbox must hide the host: a real macOS command that exists outside is "command not found" inside,
# HOME and MACHAR_FS_ROOT are the scenario's directories, and CI does not leak in from the caller.
_zz_isolation_check() {
    if defaults read NSGlobalDomain AppleLocale >/dev/null 2>&1; then
        record_result "$1" "$2" "$3" "FAIL" "$4" "the host defaults command leaked into the sandbox" ""
    elif [[ "$HOME" != "${ZZ_EXPECTED_HOME:-}" || "${MACHAR_FS_ROOT:-}" != "${ZZ_EXPECTED_ROOT:-}" ]]; then
        record_result "$1" "$2" "$3" "FAIL" "$4" "HOME or MACHAR_FS_ROOT is not the sandbox" ""
    elif [[ -n "${CI:-}" ]]; then
        record_result "$1" "$2" "$3" "INFO" "$4" "CI is set" ""
    else
        record_result "$1" "$2" "$3" "PASS" "$4" "isolated" ""
    fi
}

scenario_begin ZZ-03 "the sandbox hides host commands and replaces HOME and the root" _zz_isolation_check
    sc_env ZZ_EXPECTED_HOME="$SC_HOME"
    sc_env ZZ_EXPECTED_ROOT="$SC_ROOT"
    expect PASS --details 'isolated'
scenario_end

CI=leaked-from-the-caller scenario_begin ZZ-03 "CI from the caller does not leak into the sandbox" _zz_isolation_check
    sc_env ZZ_EXPECTED_HOME="$SC_HOME"
    sc_env ZZ_EXPECTED_ROOT="$SC_ROOT"
    expect PASS --details 'isolated'
scenario_end

scenario_begin ZZ-03 "a scenario can set CI explicitly" _zz_isolation_check
    sc_env ZZ_EXPECTED_HOME="$SC_HOME"
    sc_env ZZ_EXPECTED_ROOT="$SC_ROOT"
    sc_env CI=1
    expect INFO --details 'CI is set'
scenario_end

# --- pure helpers -------------------------------------------------------------
sc_judge NOT_PASS INFO "x" "";  sc_assert "$?" "NOT_PASS accepts INFO"
sc_judge NOT_PASS PASS "x" "";  sc_assert "$((1 - $? ))" "NOT_PASS rejects PASS"
sc_judge NOT_PASS NONE "x" "";  sc_assert "$((1 - $? ))" "NOT_PASS rejects a missing result"
sc_judge WARN WARN "abc" "b";   sc_assert "$?" "a matching details pattern is accepted"
sc_judge WARN WARN "abc" "z";   sc_assert "$((1 - $? ))" "a non-matching details pattern is rejected"
sc_judge PASS WARN "abc" "";    sc_assert "$((1 - $? ))" "a different status is rejected"

quoted="$(sc_q "it's a 'test'")"
sc_assert "$([[ "$(sh -c "printf '%s' $quoted")" == "it's a 'test'" ]] && echo 0 || echo 1)" "sc_q quotes single quotes for sh"

# The call log records what a check ran, which is how expect_no_call works.
scenario_begin ZZ-02 "the call log records invocations" _zz_selftest_check
    shim fakecmd --when '--probe' --out green
    sc_exec ZZ-02 _zz_selftest_check >/dev/null
    sc_assert "$(grep -q '^fakecmd --probe' "$SC_LOG" && echo 0 || echo 1)" "the call log contains the probe"
    rm -rf "$SC_DIR"
