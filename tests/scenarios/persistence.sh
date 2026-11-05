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

# PERS-02: LaunchDaemons under /Library/LaunchDaemons (fake root). plutil and codesign are shimmed.
scenario_begin PERS-02 "a daemon with a valid signed binary passes"
    fs /Library/LaunchDaemons/com.example.good.plist 'plist'
    shim plutil --when 'extract Program raw' --out '/bin/sh'
    shim codesign --exit 0
    expect PASS --details 'Inspected 1 LaunchDaemons'
scenario_end

scenario_begin PERS-02 "a daemon running from /tmp is flagged"
    fs /Library/LaunchDaemons/com.example.tmp.plist 'plist'
    shim plutil --when 'extract Program raw' --out '/tmp/payload'
    expect WARN --details 'temporary path'
scenario_end

scenario_begin PERS-02 "a root daemon pointing into a user home is flagged"
    fs /Library/LaunchDaemons/com.example.home.plist 'plist'
    shim plutil --when 'extract Program raw' --out '/Users/someone/bin/agent'
    expect WARN --details 'user home'
scenario_end

scenario_begin PERS-02 "a daemon whose binary is missing is flagged"
    fs /Library/LaunchDaemons/com.example.gone.plist 'plist'
    shim plutil --when 'extract Program raw' --out '/no/such/binary'
    expect WARN --details 'missing binary'
scenario_end

scenario_begin PERS-02 "an unsigned daemon binary is flagged"
    fs /Library/LaunchDaemons/com.example.unsigned.plist 'plist'
    shim plutil --when 'extract Program raw' --out '/bin/sh'
    shim codesign --exit 1
    expect WARN --details 'unsigned'
scenario_end

scenario_begin PERS-02 "a missing LaunchDaemons directory is not a pass"
    expect INFO --details 'not found'
scenario_end

scenario_begin PERS-02 "plists that cannot be parsed are not a pass"
    fs /Library/LaunchDaemons/com.example.opaque.plist 'plist'
    expect INFO --details 'Could not read'
scenario_end

scenario_begin PERS-02 "skipping signature verification is stated in the details"
    fs /Library/LaunchDaemons/com.example.good.plist 'plist'
    shim plutil --when 'extract Program raw' --out '/bin/sh'
    expect PASS --details 'code signatures were not verified'
scenario_end

seams_complete PERS-02
seams_complete PERS-04
