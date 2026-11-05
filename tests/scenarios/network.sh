#!/bin/zsh
echo "\n\033[1m[Scenarios] Network\033[0m"

# NET-02: socketfilterfw is reached through MACHAR_SOCKETFILTERFW; the fallback is the alf preference.
scenario_begin NET-02 "stealth mode on passes"
    shim socketfilterfw --when '--getstealthmode' --out 'Firewall stealth mode is on'
    sc_env MACHAR_SOCKETFILTERFW="$SC_BIN/socketfilterfw"
    expect PASS
scenario_end

scenario_begin NET-02 "stealth mode off is a suggestion"
    shim socketfilterfw --when '--getstealthmode' --out 'Firewall stealth mode is off'
    sc_env MACHAR_SOCKETFILTERFW="$SC_BIN/socketfilterfw"
    expect SUGG
scenario_end

scenario_begin NET-02 "the preference fallback passes when stealthenabled is 1"
    shim defaults --when 'stealthenabled' --out 1
    sc_env MACHAR_SOCKETFILTERFW="$SC_ROOT/absent"
    expect PASS
scenario_end

scenario_begin NET-02 "no firewall tool and no preference is not a pass"
    sc_env MACHAR_SOCKETFILTERFW="$SC_ROOT/absent"
    expect INFO --details 'could not be read'
scenario_end

scenario_begin NET-02 "unrecognized firewall output is not a pass"
    shim socketfilterfw --when '--getstealthmode' --out 'unexpected text'
    sc_env MACHAR_SOCKETFILTERFW="$SC_BIN/socketfilterfw"
    expect INFO
scenario_end

# NET-06: lsof output format, header line first; wildcard listeners of third-party processes are flagged.
_LSOF_HEAD='COMMAND     PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME'

scenario_begin NET-06 "a third-party wildcard listener is flagged"
    shim lsof --out "$_LSOF_HEAD"$'\ndevserver  4242 dev    10u  IPv4 0x1234      0t0  TCP *:8080 (LISTEN)'
    shim ps --out '/usr/local/bin/devserver'
    expect WARN --details 'devserver'
scenario_end

scenario_begin NET-06 "loopback and Apple system listeners pass"
    shim lsof --out "$_LSOF_HEAD"$'\nrapportd   300 dev    10u  IPv4 0x1235      0t0  TCP *:49152 (LISTEN)\ndevserver  4242 dev    11u  IPv4 0x1236      0t0  TCP 127.0.0.1:3000 (LISTEN)'
    shim ps --out '/usr/local/bin/devserver'
    expect PASS --details 'visible to the current user'
scenario_end

scenario_begin NET-06 "a missing lsof is not a pass"
    expect INFO --details 'could not be enumerated'
scenario_end

scenario_begin NET-06 "an lsof that returns nothing is not a pass"
    shim lsof --exit 1
    expect INFO
scenario_end

seams_complete NET-02
seams_complete NET-06
