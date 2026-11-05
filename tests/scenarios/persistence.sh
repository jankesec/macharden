#!/bin/zsh
echo "\n\033[1m[Scenarios] Persistence\033[0m"

# PERS-04: login items cannot be read without a prompt, so the check never reports PASS and never runs a
# tool that can prompt (osascript asks for Automation consent, sfltool dumpbtm waits for authorization).
scenario_begin PERS-04 "reports INFO and never calls a tool that can prompt"
    shim osascript --out 'Slack, Dropbox'
    shim sfltool --out 'Name: Example'
    expect INFO --details 'System Settings'
    expect_no_call osascript
    expect_no_call sfltool
scenario_end

scenario_begin PERS-04 "reports INFO in a CI environment"
    sc_env CI=1
    expect INFO
scenario_end

scenario_begin PERS-04 "reports INFO when no tool is available"
    expect INFO
scenario_end

seams_complete PERS-04
