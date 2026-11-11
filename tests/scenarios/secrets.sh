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

# stat differs between platforms. GNU stat (Linux, used by CI) treats -f as "file system status": it prints a
# status block and exits 0 instead of failing, so the BSD form must never be tried before the GNU form.
scenario_begin SEC-05 "GNU stat output (Linux) is understood"
    home .ssh/
    home .ssh/id_ed25519 'key'
    home .ssh/config 'Host *'
    shim stat --when "-c %a $SC_HOME/.ssh/id_ed25519" --out 600
    shim stat --when "-c %a $SC_HOME/.ssh/config" --out 600
    shim stat --when "-c %a $SC_HOME/.ssh" --out 700
    shim stat --when '-f' --out $'  File: "x"\n    ID: 1 Namelen: 255     Type: ext2/ext3\nBlock size: 4096'
    expect PASS
scenario_end

scenario_begin SEC-05 "BSD stat output (macOS) is understood"
    home .ssh/
    home .ssh/id_ed25519 'key'
    shim stat --when "-f %OLp $SC_HOME/.ssh/id_ed25519" --out 600
    shim stat --when "-f %OLp $SC_HOME/.ssh" --out 700
    expect PASS
scenario_end

seams_complete SEC-05
