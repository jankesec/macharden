#!/bin/zsh
echo "\n\033[1m[Scenarios] Secrets\033[0m"

# SEC-05: ~/.ssh permissions, evidence = real files in the fake HOME.
scenario_begin SEC-05 "no ~/.ssh directory means nothing to protect"
    expect PASS --details 'No ~/.ssh'
scenario_end

scenario_begin SEC-05 "700 directory, 600 key and 600 config pass"
    home .ssh/
    home .ssh/id_ed25519 'key'
    home .ssh/config 'Host *'
    home_mode 700 .ssh; home_mode 600 .ssh/id_ed25519; home_mode 600 .ssh/config
    expect PASS
scenario_end

scenario_begin SEC-05 "a world-readable private key is flagged"
    home .ssh/
    home .ssh/id_ed25519 'key'
    home_mode 700 .ssh; home_mode 644 .ssh/id_ed25519
    expect WARN --details 'id_ed25519'
scenario_end

scenario_begin SEC-05 "a group-accessible directory is flagged"
    home .ssh/
    home_mode 755 .ssh
    expect WARN --details '~/.ssh directory'
scenario_end

scenario_begin SEC-05 "loose config permissions are flagged"
    home .ssh/
    home .ssh/config 'Host *'
    home_mode 700 .ssh; home_mode 644 .ssh/config
    expect WARN --details 'config'
scenario_end

scenario_begin SEC-05 "unreadable permissions are not a pass"
    home .ssh/
    without stat
    expect INFO --details 'Could not read'
scenario_end

seams_complete SEC-05
