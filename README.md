# 🛡️ macharden

<p align="center">
  <strong>Modern macOS Security Hardening, Audit & Remediation Engine</strong><br>
  <em>Zero dependencies. Native macOS inspection. Weighted scoring. Automated remediation.</em>
</p>

<p align="center">
  <a href="https://github.com/macharden/macharden/actions"><img src="https://img.shields.io/badge/CI-passing-brightgreen.svg?logo=githubactions&logoColor=white" alt="CI Status"></a>
  <a href="#license"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
  <a href="https://apple.com/macos"><img src="https://img.shields.io/badge/Platform-macOS%2012%2B%20%7C%20Apple%20Silicon%20%26%20Intel-black.svg?logo=apple&logoColor=white" alt="Platform: macOS"></a>
  <a href="#"><img src="https://img.shields.io/badge/Shell-Zsh%20%2F%20Bash-orange.svg" alt="Shell: Zsh / Bash"></a>
  <a href="#audit-categories--checks"><img src="https://img.shields.io/badge/Audits-44%2B%20Controls-purple.svg" alt="Audit Checks"></a>
  <a href="#"><img src="https://img.shields.io/badge/Dependencies-Zero%20(Pure%20Native)-success.svg" alt="Dependencies"></a>
</p>

---

## 📖 Overview

**macharden** is an enterprise-grade security audit and automated hardening scanner designed specifically for macOS (macOS Monterey through macOS Sequoia and beyond, supporting both Apple Silicon and Intel).

Unlike generic Unix scanners that treat macOS as a generic BSD derivative, **macharden** probes macOS-exclusive security architectures: **System Integrity Protection (SIP)**, **FileVault 2**, **Gatekeeper**, **Application Firewall (`socketfilterfw`)**, **Keychain lock timeouts**, **BPF packet capture privileges**, **LaunchAgents / LaunchDaemons persistence**, **plaintext API token leaks in shell configurations**, and **SSH permissions**.

---

## 🎯 Why macharden?

Security engineers, DevOps professionals, and privacy-conscious Mac users face a common problem:

1. **Linux tools like Lynis** do not understand Apple-specific technologies (`socketfilterfw`, FileVault, Launchd plist target validation, Gatekeeper assessments).
2. **Apple CIS Benchmarks & mSCP (macOS Security Compliance Project)** are tailored for enterprise fleets managed by heavy MDM (Mobile Device Management) platforms like Jamf or Kandji, requiring cumbersome XML/SCAP configurations.
3. **Hardening guides (e.g. drduh's guide)** provide excellent advice but require hours of manual reading, terminal typing, and risk user error.

**macharden** bridges this gap: **a single command audits your system, computes an objective Hardening Index (0–100%), and generates an executable remediation script to fix vulnerabilities safely.**

---

## ⚖️ Feature Comparison

| Feature | `macharden` | `Lynis` | `mSCP` (macOS Compliance) | `drduh Guide` |
| :--- | :---: | :---: | :---: | :---: |
| **macOS Native Architecture Focus** | **Yes (100%)** | Partial (BSD generic) | Yes | Yes |
| **Zero External Dependencies** | **Yes (Pure Zsh/Bash)** | Yes (POSIX) | No (Python/Ruby) | Manual |
| **Objective Hardening Index (0–100%)** | **Yes (Weighted)** | Yes (Hardening index) | No (Pass/Fail) | No |
| **Interactive One-Key Fixer (`--fix`)** | **Yes** | No | No | No |
| **Standalone Fix Script Generator (`--generate-fix`)** | **Yes** | No | No (Puppet/Chef) | Manual |
| **Plaintext Shell & `.env` Secrets Scanner** | **Yes** | No | No | No |
| **Firewall Exception Permissiveness Audit** | **Yes** | No | Basic | Manual |
| **BPF Packet Sniffing & Daemon Checks** | **Yes** | No | No | Manual |
| **Export Formats** | **Terminal, Markdown, JSON, HTML** | Text, DAT | XML, SCAP | None |
| **Non-MDM / Developer Machine Ready** | **Yes (Instant)** | Yes | No (Complex setup) | Manual |

---

## 🚀 Quick Start

### Option 1: One-Liner Quick Scan (No Git required)

Run an immediate, read-only security audit:

```bash
curl -fsSL https://raw.githubusercontent.com/macharden/macharden/main/bin/macharden | zsh
```

### Option 2: Clone & Run

```bash
# Clone the repository
git clone https://github.com/macharden/macharden.git
cd macharden

# Execute the security scan
./bin/macharden
```

### Option 3: System-Wide Installation

```bash
# Install binary, shell autocompletions (Zsh & Bash), and UNIX man page
make install

# Or install individual components:
make install-completions   # Zsh (_macharden) & Bash autocompletions
make install-man           # UNIX manual page (man macharden)
```

*(Installs binary to `/usr/local/bin` or `~/.local/bin`, shell completions to Zsh/Bash site-functions, and man page to `share/man/man1/macharden.1`)*

---

## 💻 CLI Usage & Examples

```text
macharden - macOS Security Hardening & Audit Scanner (v1.3.0)

Usage:
  macharden [options]

Options:
  -h, --help                 Display this help message and exit
  -v, --version              Print version information and exit
  -c, --category <name>      Run specific category of audit checks
                             Categories: hardening, network, secrets, persistence, all (default: all)
  -f, --format <format>      Output report format: term, markdown, json, html (default: term)
  -o, --output <file>        Save audit report to the specified file path
  -q, --quiet                Minimal output, print only final executive summary
  --fix                      Interactively prompt and apply remediation fixes for failed checks
  --generate-fix [file]      Generate automated remediation shell script without applying
  --no-color                 Disable ANSI terminal color output
  --skip-test <id>[,id...]   Skip check IDs (repeatable)
  --profile <file>           Load skip-test=ID lines from a profile
  --no-profile               Do not auto-load ~/.macharden/profile
  --compliance <framework>   Align report with cis, nist, mitre, or all
  --daemon-install [sched]   Install LaunchAgent (daily, weekly, monthly, on-login)
  --daemon-uninstall         Unload and remove background scan LaunchAgent
  --daemon-status            Show background daemon status and recent logs
  --alert                    Native macOS notification on critical findings
```

### Common Commands

```bash
# 1. Run a full system audit with rich terminal output
macharden

# 2. Audit only network controls (firewall, BPF sniffing, listeners)
macharden -c network

# 3. Export a compliance audit report as GitHub-flavored Markdown
macharden -f markdown -o audit_report.md

# 4. Generate a structured JSON report for SIEM / CI pipelines
macharden -f json -o audit_report.json

# 5. Generate a standalone, reviewable fix script without making immediate changes
macharden --generate-fix fix_hardening.sh

# 6. Interactively review and apply remediation commands one-by-one
macharden --fix

# 7. Quiet mode: print only the executive score summary
macharden -q

# 8. Interactive HTML dashboard
macharden -f html -o audit.html

# 9. CIS-aligned compliance report
macharden --compliance cis

# 10. Schedule a weekly background audit
macharden --daemon-install weekly
```

---

## 🖥️ Sample Terminal Output

```text
                   _                     _            
  _ __ ___   __ _  ___| |__   __ _ _ __   __| | ___ _ __  
 | '_ ` _ \ / _` |/ __| '_ \ / _` | '__| / _` |/ _ \ '_ \ 
 | | | | | | (_| | (__| | | | (_| | |   | (_| |  __/ | | |
 |_| |_| |_|\__,_|\___|_| |_|\__,_|_|    \__,_|\___|_| |_|
  macOS Security Hardening & Audit Scanner  v1.3.0
──────────────────────────────────────────────────────────────────────
 Target Host:   macOS-Workstation (auditor)
 macOS Build:   macOS 15.3 (Build 24D60) [arm64]
 Audit Time:    2026-09-12 12:00:00 UTC
──────────────────────────────────────────────────────────────────────

▶ Hardening Audit Checks
----------------------------------------------------------------------
  [PASS]  HARD-01      System Integrity Protection (SIP)
        ↳ System Integrity Protection (SIP) is enabled and enforcing kernel/filesystem restrictions.
  [PASS]  HARD-02      FileVault Full Disk Encryption
        ↳ FileVault 2 full disk encryption is active on boot volume.
  [PASS]  HARD-03      Gatekeeper Code Execution Verification
        ↳ Gatekeeper assessment subsystem is active.
  [PASS]  HARD-04      Screen Saver Lock and Delay
        ↳ Screen lock requires password immediately (0 second delay).
  [PASS]  HARD-05      Guest Account Restrictions
        ↳ Guest account is disabled.
  [PASS]  HARD-06      Automatic Software Updates
        ↳ Automatic update checks and background security data installations enabled.
  [PASS]  HARD-07      Sharing Services Attack Surface
        ↳ Remote login, file sharing, remote management, and remote apple events disabled.

▶ Network Audit Checks
----------------------------------------------------------------------
  [PASS]  NET-01      Application Firewall Global State
        ↳ Application Firewall is active (socketfilterfw state: 1).
  [PASS]  NET-02      Firewall Stealth Mode
        ↳ Firewall stealth mode enabled (drops unprompted ICMP and port probes).
  [WARN]  NET-03      Firewall Permissive Exceptions
        ↳ Dangerous interpreters allowed incoming traffic: Python.app
  [WARN]  NET-04      BPF Packet Capture Permissions
        ↳ Non-root packet sniffing permitted: user in 'access_bpf' group.
  [PASS]  NET-05      Hosts File Loopback Integrity
        ↳ /etc/hosts properly resolves IPv4 127.0.0.1 and IPv6 ::1 localhost.
  [PASS]  NET-06      Listening Services Exposure
        ↳ No unencrypted services listening on external interfaces (0.0.0.0 / *).

▶ Secrets Audit Checks
----------------------------------------------------------------------
  [FAIL]  SEC-01      Plaintext API Keys in Shell Profiles
        ↳ Plaintext secrets found in shell profiles (4): .zshrc:6 (H1_API_TOKEN=***)
  [WARN]  SEC-02      Exposed .env Configuration Files
        ↳ World-readable .env secret files found (5): ~/Documents/Projects/.env (644)
  [PASS]  SEC-03      Keychain Auto-Lock Settings
        ↳ Login keychain configured with automatic lock timeout.
  [PASS]  SEC-04      Kernel Memory Core Dumps
        ↳ Kernel coredump generation disabled (kern.coredump: 0).
  [WARN]  SEC-05      SSH Keys and Config Permissions
        ↳ SSH config file has insecure permissions (644, expected 600).

▶ Persistence Audit Checks
----------------------------------------------------------------------
  [PASS]  PERS-01     User & System LaunchAgents
        ↳ All LaunchAgents reviewed and validated.
  [WARN]  PERS-02     System LaunchDaemons Review
        ↳ Broken LaunchDaemons pointing to non-existent binaries detected.
  [PASS]  PERS-03     Cron Jobs Review
        ↳ No unauthorized cron jobs registered.
  [PASS]  PERS-04     Login Items Persistence
        ↳ Login items inspected and accounted for.
  [PASS]  PERS-05     SSH Authorized Keys Review
        ↳ ~/.ssh/authorized_keys absent or clean.
  [PASS]  PERS-06     Sudoers Configuration
        ↳ No unauthorized NOPASSWD or sudoers.d additions found.

======================================================================
                     EXECUTIVE AUDIT SUMMARY
======================================================================

  Hardening Index: [████████████████████████░░░░░░]  82.0% (GOOD / ACCEPTABLE)

  Total Checks Audited:    24
  Passed Checks:           15
  Warnings:                5
  Failed Checks:           1
  Informational:           2
  Suggestions:             1
  Score Points Earned:     120.5 / 147.0

▶ High Priority Remediation Actions:
----------------------------------------------------------------------
  [FAIL]  SEC-01     Plaintext API Keys in Shell Profiles (Weight: 9, Category: secrets)
        Finding: Plaintext secrets found in shell profiles (4): .zshrc:6 (H1_API_TOKEN=***)
        Fix:     Remove hardcoded API keys and store them in macOS Keychain. Set permissions: chmod 600 ~/.zshrc

  [WARN]  NET-03     Firewall Permissive Exceptions (Weight: 8, Category: network)
        Finding: Dangerous interpreters/tools allowed incoming connections: Python.app
        Fix:     sudo /usr/libexec/ApplicationFirewall/socketfilterfw --blockapp "<path>"

  [WARN]  NET-04     BPF Packet Capture Permissions (Weight: 7, Category: network)
        Finding: Non-root packet sniffing permitted: user in 'access_bpf' group.
        Fix:     sudo dseditgroup -o edit -d $(whoami) -t user access_bpf; sudo chmod 600 /dev/bpf*
```

---

## 🔍 Audit Categories & Checks

`macharden` inspects **44+ security controls** across four essential categories:

### 1. 🛡️ OS Hardening (`hardening`)
| Check ID | Control Title | Description | Weight |
| :--- | :--- | :--- | :---: |
| `HARD-01` | System Integrity Protection | Validates kernel, NVRAM, and root filesystem integrity (`csrutil status`) | 10 |
| `HARD-02` | FileVault Disk Encryption | Verifies full disk XTS-AES-128 encryption on APFS boot volumes | 10 |
| `HARD-03` | Gatekeeper Code Verification | Verifies system-wide code signature and notarization checks (`spctl`) | 10 |
| `HARD-04` | Screen Lock & Delay | Verifies screensaver password prompt and timeout (`<= 5s`) | 7 |
| `HARD-05` | Guest Account Access | Ensures guest login window accounts are disabled | 6 |
| `HARD-06` | Automatic Software Updates | Verifies automatic update checks and background security response downloads | 6 |
| `HARD-07` | Sharing Services Attack Surface | Verifies SMB, NFS, TFTP, SSH (`sshd`), Screen Sharing, and Remote Apple Events are inactive | 7 |
| `HARD-08` | Firmware Password / Recovery Lock | Intel firmware password (`firmwarepasswd`); Apple Silicon reported as informational | 8 |
| `HARD-09` | Secure Boot / Authenticated Root | Verifies `csrutil authenticated-root` and Apple Silicon Full Security | 8 |
| `HARD-10` | Automatic Login Disabled | Ensures `autoLoginUser` is not set on the login window | 6 |
| `HARD-11` | Bluetooth Sharing | Ensures Bluetooth file sharing services are disabled | 5 |
| `HARD-12` | Home Directory Permissions | Ensures `$HOME` is 700/750 (Lynis HOME-9304 analogue) | 6 |
| `HARD-13` | Network Time Synchronization | Verifies macOS network time (`systemsetup -getusingnetworktime`) | 5 |
| `HARD-14` | Built-in Malware Protection | Verifies Apple XProtect/MRT presence | 6 |
| `HARD-15` | USB Restricted Mode | Ensures accessories cannot attach while locked (T2 / Apple Silicon) | 5 |

### 2. 🌐 Network Security (`network`)
| Check ID | Control Title | Description | Weight |
| :--- | :--- | :--- | :---: |
| `NET-01` | Application Firewall State | Verifies that the native macOS application firewall is active | 8 |
| `NET-02` | Firewall Stealth Mode | Verifies stealth mode is active (ignores ping and unprompted port sweeps) | 5 |
| `NET-03` | Firewall Binary Exceptions | Scans allowed incoming apps for dangerous script interpreters (`python`, `bash`, `node`) | 8 |
| `NET-04` | BPF Packet Capture Rights | Audits `/dev/bpf*` device permissions and unprivileged packet sniffing access | 7 |
| `NET-05` | Hosts File Loopback Integrity | Ensures `127.0.0.1` and `::1` localhost definitions are intact in `/etc/hosts` | 9 |
| `NET-06` | Listening Wildcard Services | Audits non-Apple daemon processes bound to wildcard addresses (`0.0.0.0` / `*`) | 6 |
| `NET-07` | AirDrop | Ensures AirDrop is disabled or the AWDL radio is down | 6 |
| `NET-08` | Internet Sharing | Ensures Internet Sharing / NAT is disabled | 7 |
| `NET-09` | Firewall Logging | Verifies Application Firewall logging mode is enabled | 4 |
| `NET-10` | IP Forwarding | Ensures `net.inet.ip.forwarding` is 0 | 7 |
| `NET-11` | Promiscuous Interfaces | Flags NICs in PROMISC mode | 6 |

### 3. 🔑 Secrets & Privacy (`secrets`)
| Check ID | Control Title | Description | Weight |
| :--- | :--- | :--- | :---: |
| `SEC-01` | Shell Profile Secrets | Scans `~/.zshrc`, `~/.bashrc`, etc. for plaintext API keys, AWS tokens, OpenAI keys | 9 |
| `SEC-02` | Exposed `.env` Configuration Files | Scans user project directories for world-readable `.env` files | 6 |
| `SEC-03` | Keychain Inactivity Auto-Lock | Verifies login keychain timeout auto-lock (`security show-keychain-info`) | 5 |
| `SEC-04` | Kernel Core Memory Dumps | Verifies that crash coredumps do not dump process memory to disk (`kern.coredump`) | 5 |
| `SEC-05` | SSH Keys & Config Permissions | Audits file permissions of `~/.ssh/` (`700`), private keys (`600`), and `config` (`600`) | 7 |
| `SEC-06` | Unencrypted SSH Private Keys | Detects private keys without a passphrase | 8 |
| `SEC-07` | Secrets in Shell History | Scans `~/.zsh_history` / `~/.bash_history` for plaintext API tokens | 7 |
| `SEC-08` | SSH Daemon Hardening | When Remote Login is on, checks PermitRootLogin / MaxAuthTries / X11 | 7 |
| `SEC-09` | Suspicious Shell History Files | Detects history files that are not regular files (Lynis HOME-9310) | 5 |

### 4. ⚙️ Persistence & System Integrity (`persistence`)
| Check ID | Control Title | Description | Weight |
| :--- | :--- | :--- | :---: |
| `PERS-01` | User & System LaunchAgents | Audits plists in `~/Library/LaunchAgents` and `/Library/LaunchAgents` | 7 |
| `PERS-02` | System LaunchDaemons | Scans `/Library/LaunchDaemons` for broken, missing target binaries or unsigned jobs | 7 |
| `PERS-03` | User & System Crontabs | Audits `crontab -l` and `/etc/cron*` tables for unauthorized periodic executions | 6 |
| `PERS-04` | Login Items Persistence | Queries user login items via macOS System Events service | 5 |
| `PERS-05` | SSH Authorized Keys | Audits `~/.ssh/authorized_keys` for unauthorized SSH backdoors | 7 |
| `PERS-06` | Sudoers Configuration | Inspects `/etc/sudoers.d/` for dangerous `NOPASSWD` privilege escalation rules | 8 |
| `PERS-07` | Privileged Helper Tools | Reviews `/Library/PrivilegedHelperTools` for unsigned helpers | 6 |
| `PERS-08` | Printer Sharing | Ensures CUPS printer sharing is disabled | 5 |
| `PERS-09` | Sudo Timestamp Timeout | Ensures `timestamp_timeout` is 5 minutes or less | 5 |

---

## 🛠️ Automated Remediation Engine

`macharden` does not just identify vulnerabilities—it provides two safe, robust mechanisms to resolve them:

### 1. Generated Hardening Script (`--generate-fix`)
Creates a standalone, fully documented executable shell script containing only the necessary remediation commands:

```bash
./bin/macharden --generate-fix fix_hardening.sh
```

Review the script, inspect the exact commands, and run when ready:
```bash
sudo ./fix_hardening.sh
```

### 2. Interactive Guided Remediation (`--fix`)
Steps through every failed or warning check interactively:
- Displays finding details and the exact command to execute.
- Prompts `[y]es / [n]o / [a]ll / [q]uit` before applying each change.
- Reports a final summary of applied, skipped, and failed remediations.

```bash
./bin/macharden --fix
```

---

## 🧪 Testing & Continuous Integration

`macharden` has a comprehensive automated test framework and CI pipeline:

```bash
# Run syntax validation (zsh -n & bash -n) and all unit tests
make test

# Run code linter
make lint

# Execute clean
make clean
```

### Test Coverage includes:
- **0 Syntax Errors Guarantee**: Every script is validated through both `zsh -n` and `bash -n`.
- **Scoring Normalization**: Unit tests verify 0–100% boundary conditions, status weighting (PASS = 100%, WARN = 50%, FAIL = 0%, INFO/SUGG = neutral), and point summation.
- **Report Validation**: JSON reports are verified against JSON specification via `python3 -m json.tool`.
- **Remediation Script Testing**: Generated fix scripts are syntax-checked and validated for executable bit permissions.

---

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository.
2. Create your feature branch: `git checkout -b feature/new-audit-check`
3. Add your check to the appropriate `lib/audit_*.sh` module.
4. Ensure all tests pass: `make test`
5. Commit your changes: `git commit -m 'feat(audit): add Bluetooth sharing check'`
6. Push to your branch and submit a Pull Request.

---

## 📄 License

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for complete details.

Copyright (c) 2026 macharden contributors.
