#!/bin/zsh
echo "\n\033[1m[Scenarios] Hardening\033[0m"

# HARD-06: com.apple.SoftwareUpdate preferences; softwareupdate --schedule when AutomaticCheckEnabled is unset.
scenario_begin HARD-06 "checking, installing, critical and config updates all enabled pass"
    shim defaults --when 'AutomaticCheckEnabled' --out 1
    shim defaults --when 'AutomaticallyInstallMacOSUpdates' --out 1
    shim defaults --when 'CriticalUpdateInstall' --out 1
    shim defaults --when 'ConfigDataInstall' --out 1
    expect PASS
scenario_end

scenario_begin HARD-06 "automatic checking turned off warns"
    shim defaults --when 'AutomaticCheckEnabled' --out 0
    shim defaults --when 'AutomaticallyInstallMacOSUpdates' --out 1
    shim defaults --when 'CriticalUpdateInstall' --out 1
    shim defaults --when 'ConfigDataInstall' --out 1
    expect WARN --details 'checking'
scenario_end

scenario_begin HARD-06 "critical updates not installed warns"
    shim defaults --when 'AutomaticCheckEnabled' --out 1
    shim defaults --when 'AutomaticallyInstallMacOSUpdates' --out 1
    shim defaults --when 'CriticalUpdateInstall' --out 0
    shim defaults --when 'ConfigDataInstall' --out 1
    expect WARN --details 'critical'
scenario_end

scenario_begin HARD-06 "background installation off is a suggestion"
    shim defaults --when 'AutomaticCheckEnabled' --out 1
    shim defaults --when 'AutomaticallyInstallMacOSUpdates' --out 0
    shim defaults --when 'CriticalUpdateInstall' --out 1
    shim defaults --when 'ConfigDataInstall' --out 1
    expect SUGG
scenario_end

scenario_begin HARD-06 "an unset check key falls back to softwareupdate --schedule"
    shim defaults --when 'AutomaticallyInstallMacOSUpdates' --out 1
    shim defaults --when 'CriticalUpdateInstall' --out 1
    shim defaults --when 'ConfigDataInstall' --out 1
    shim softwareupdate --when '--schedule' --out 'Automatic checking for updates is turned on'
    expect PASS
scenario_end

scenario_begin HARD-06 "no readable update settings is not a pass"
    expect INFO --details 'could not be read'
scenario_end

# HARD-07: sharing services. netstat lists listening sockets without administrator access.
_NETSTAT_HEAD=$'Active Internet connections (including servers)\nProto Recv-Q Send-Q  Local Address          Foreign Address        (state)'
_NETSTAT_QUIET="$_NETSTAT_HEAD"$'\ntcp4       0      0  127.0.0.1.631          *.*                    LISTEN\ntcp6       0      0  *.49152                *.*                    LISTEN'

scenario_begin HARD-07 "no sharing listener passes"
    shim netstat --out "$_NETSTAT_QUIET"
    expect PASS --details 'No remote sharing listeners'
scenario_end

scenario_begin HARD-07 "a listener on TCP 22 is Remote Login"
    shim netstat --out "$_NETSTAT_QUIET"$'\ntcp4       0      0  *.22                   *.*                    LISTEN'
    expect WARN --details 'SSH'
scenario_end

scenario_begin HARD-07 "a listener on TCP 445 is File Sharing"
    shim netstat --out "$_NETSTAT_QUIET"$'\ntcp4       0      0  *.445                  *.*                    LISTEN'
    expect WARN --details 'SMB'
scenario_end

scenario_begin HARD-07 "a listener on TCP 2049 is NFS and fails"
    shim netstat --out "$_NETSTAT_QUIET"$'\ntcp4       0      0  *.2049                 *.*                    LISTEN'
    expect FAIL --details 'NFS'
scenario_end

scenario_begin HARD-07 "a listener on TCP 5900 is Screen Sharing"
    shim netstat --out "$_NETSTAT_QUIET"$'\ntcp4       0      0  *.5900                 *.*                    LISTEN'
    expect WARN --details 'Screen Sharing'
scenario_end

scenario_begin HARD-07 "a listener on TCP 3031 is Remote Apple Events"
    shim netstat --out "$_NETSTAT_QUIET"$'\ntcp4       0      0  *.3031                 *.*                    LISTEN'
    expect WARN --details 'Remote Apple Events'
scenario_end

scenario_begin HARD-07 "without netstat and without any signal the result is not a pass"
    expect INFO --details 'could not'
scenario_end

scenario_begin HARD-07 "launchctl evidence still counts without netstat"
    shim launchctl --when 'list com.apple.smbd' --out '{ "Label" = "com.apple.smbd"; };'
    expect WARN --details 'SMB'
scenario_end

scenario_begin HARD-07 "systemsetup saying Remote Login is On still counts without netstat"
    shim systemsetup --when '-getremotelogin' --out 'Remote Login: On'
    expect WARN --details 'SSH'
scenario_end

seams_complete HARD-06
seams_complete HARD-07
