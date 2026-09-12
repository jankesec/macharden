# 🛡️ macharden

<p align="center">
  <strong>Modern macOS Security Hardening, Audit & Remediation Engine</strong><br>
  <em>Zero dependencies. Native macOS inspection. Baseline drift engine. OASIS SARIF v2.1.0. Automated remediation.</em>
</p>

<p align="center">
  <a href="https://github.com/jankesec/macharden/actions"><img src="https://img.shields.io/badge/CI-passing-brightgreen.svg?logo=githubactions&logoColor=white" alt="CI Status"></a>
  <a href="#-license"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
  <a href="https://apple.com/macos"><img src="https://img.shields.io/badge/Platform-macOS%2012%2B%20%7C%20Apple%20Silicon%20%26%20Intel-black.svg?logo=apple&logoColor=white" alt="Platform: macOS"></a>
  <a href="#"><img src="https://img.shields.io/badge/Shell-Zsh%20%2F%20Bash-orange.svg" alt="Shell: Zsh / Bash"></a>
  <a href="#-audit-categories--50-rules"><img src="https://img.shields.io/badge/Audits-50%20Security%20Rules-purple.svg" alt="Audit Checks"></a>
  <a href="#-compliance-frameworks"><img src="https://img.shields.io/badge/Compliance-CIS%20%7C%20NIST%20%7C%20MITRE-darkgreen.svg" alt="Compliance"></a>
  <a href="#"><img src="https://img.shields.io/badge/Dependencies-Zero%20(Pure%20Native)-success.svg" alt="Dependencies"></a>
</p>

---

## 📖 Overview

**macharden** is an enterprise-grade security audit, posture assessment, and automated hardening scanner engineered specifically for macOS (macOS Monterey through macOS Sequoia, supporting both Apple Silicon and Intel hardware).

Unlike generic Unix scanners that treat macOS as a generic BSD derivative, **macharden** inspects Apple's proprietary security architectures: **System Integrity Protection (SIP)**, **FileVault 2 XTS-AES encryption**, **Gatekeeper code assessments**, **Application Firewall (`socketfilterfw`)**, **Keychain lock timeouts**, **BPF packet capture privileges**, **LaunchAgents / LaunchDaemons persistence**, **plaintext API token leaks in shell configurations & history**, **cloud credentials permissions (`~/.aws`, `~/.kube`, `~/.docker`)**, **insecure `$PATH` hijacking vectors**, and **SSH permissions**.

---

## 🎯 Why macharden?

Security engineers, DevOps professionals, and privacy-conscious Mac users face a common problem:

1. **Generic Unix Tools (e.g. Lynis):** Lack visibility into Apple-specific technologies (`socketfilterfw`, FileVault 2, Launchd target validation, Gatekeeper assessments, AirDrop, Apple telemetry).
2. **mSCP (macOS Security Compliance Project) & CIS Benchmarks:** Tailored primarily for enterprise fleets managed by heavy MDM (Mobile Device Management) platforms like Jamf or Kandji, requiring complex XML/SCAP configurations and administrative infrastructure.
3. **Static Hardening Guides (e.g. drduh's guide):** Provide excellent advice but require hours of manual terminal execution, risking human error and configuration drift.

**macharden** bridges this gap: **a single, zero-dependency command audits your macOS system across 50 controls, calculates an objective Hardening Index (0–100%), detects baseline regressions, and generates safe remediation scripts or applies fixes interactively.**

---

## ⚖️ Feature Comparison

| Feature / Capability | **`macharden`** | `Lynis` | `mSCP` (macOS Compliance) | `drduh Guide` |
|:---|:---:|:---:|:---:|:---:|
| **macOS Native Architecture Focus** | **Yes (100% Native)** | Partial (Generic BSD) | Yes | Yes |
| **Zero External Dependencies** | **Yes (Pure Zsh/Bash)** | Yes (POSIX) | No (Python/Ruby) | Manual |
| **50 Audited Security Controls** | **Yes (50 Rules)** | ~30 (macOS subset) | Variable (SCAP) | Static List |
| **Objective Hardening Index (0–100%)** | **Yes (Weighted)** | Yes (Index) | No (Pass/Fail) | No |
| **Baseline Drift & Diff Engine (`--diff`)** | **Yes (JSON Diff)** | Commercial Only | No | No |
| **CI/CD Quality Gate (`--fail-on-regression`)** | **Yes (Exit Code 2)**| No | No | No |
| **OASIS SARIF v2.1.0 Export (`-f sarif`)** | **Yes (GitHub Code Scanning)** | No | No | No |
| **Liquid Glass Dark Mode HTML Dashboard** | **Yes (Standalone)** | No | No | No |
| **Bilingual Support (EN / TR)** | **Yes (Real-time Toggle)**| Partial | English only | English only |
| **Interactive Remediation (`--fix`)** | **Yes (Guided)** | No | No | No |
| **Standalone Fix Script Generator (`--generate-fix`)** | **Yes (Executable)** | No | Puppet/Chef only | Manual |
| **Non-Destructive Safe Mode (`--dry-run` & `--undo`)** | **Yes** | No | No | Manual |
| **Regulatory Mappings (CIS, NIST, MITRE)** | **Yes (All 50 Rules)** | Partial | CIS only | No |

---

## 🚀 Quick Start

### 1. One-Liner Quick Scan (No Git required)

Run an immediate, read-only security audit directly in your terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/jankesec/macharden/main/bin/macharden | zsh
```

### 2. Clone & Run

```bash
# Clone repository
git clone https://github.com/jankesec/macharden.git
cd macharden

# Execute full security audit
./bin/macharden
```

### 3. System-Wide Installation

```bash
# Install binary, shell autocompletions (Zsh & Bash), and UNIX man page
make install

# Or install individual components:
make install-completions   # Zsh (_macharden) & Bash autocompletions
make install-man           # UNIX manual page (man macharden)
```

*(Installs executable to `/usr/local/bin` or `~/.local/bin`, shell completions to Zsh/Bash site-functions, and manual page to `share/man/man1/macharden.1`)*

---

## 📈 Baseline Drift & CI/CD Regression Engine

Prevent security regressions across developer machines and macOS CI runners with historical baseline tracking:

```bash
# 1. Establish an initial baseline snapshot:
macharden -f json -o baseline.json

# 2. Run future scans against the baseline:
macharden --diff baseline.json

# 3. Enforce CI/CD security gate (exits with code 2 if security degrades):
macharden --diff baseline.json --fail-on-regression
```

### Executive Drift Output:
```text
======================================================================
                  BASELINE DRIFT & SECURITY DIFF
======================================================================
  Baseline Scan : 2026-09-01 10:00:00 UTC (Host: macOS-Prod)
  Current Scan  : 2026-09-12 12:00:00 UTC (Host: macOS-Prod)
  Baseline Score: 85.0% (B+)
  Current Score : 79.5% (C+)
  Score Drift   : -5.5% [▼ REGRESSED]

  Regressions   : 2 new failing/warning check(s)
  Remediations  : 1 previously failed check(s) resolved

▶ Security Regressions (Action Required):
  [FAIL]  HARD-02  FileVault Full Disk Encryption (was PASS)
  [WARN]  NET-03   Firewall Permissive Exceptions (was PASS)

▶ Remediated Checks (Resolved):
  [PASS]  SEC-01   Plaintext API Keys in Shell Profiles (was FAIL)
```

---

## 📊 Multi-Format Reporting

Generate rich reports suited for executive leadership, compliance auditors, and automated vulnerability triage:

```bash
# Standalone Liquid Glass HTML5 Dashboard (zero CDN dependencies, bilingual with 'L' key):
macharden -f html -o report.html && open report.html

# OASIS SARIF v2.1.0 for GitHub Code Scanning / Advanced Security:
macharden -f sarif -o report.sarif

# GitHub-flavored Markdown for pull requests and issue trackers:
macharden -f markdown -o report.md

# Machine-readable JSON for SIEM / Splunk ingestion:
macharden -f json -o report.json
```

---

## 💻 CLI Usage & Flags

```text
macharden - macOS Security Hardening & Audit Scanner (v1.3.0)

Usage:
  macharden [options]

Options:
  -h, --help                 Display this help message and exit
  -v, --version              Print version information and exit
  -c, --category <name>      Run specific category (hardening, network, secrets, persistence, all)
  -f, --format <format>      Output format: term, markdown, json, html, sarif (default: term)
  -o, --output <file>        Save audit report to the specified file path
  -q, --quiet                Minimal output, print only executive summary
  -l, --lang <en|tr>         Interface language (English or Turkish; default: en)
  --diff <baseline.json>     Compare current audit results against a historical baseline
  --fail-on-regression       Exit with code 2 if security posture has regressed
  --min-score <0-100>        Exit with code 1 if hardening index falls below threshold
  --fail-on-warn             Treat warnings as failures in exit status
  --fix                      Interactively prompt and apply remediation fixes
  --dry-run                  Preview remediation commands without executing them
  --undo                     Rollback previous automated remediation actions
  --generate-fix [file]      Generate automated remediation shell script without applying
  --skip-test <id>[,id...]   Skip check IDs (repeatable)
  --profile <file>           Load skip-test=ID lines from a profile
  --no-profile               Do not auto-load ~/.macharden/profile
  --compliance <framework>   Filter report by regulatory framework (cis, nist, mitre, all)
  --daemon-install [sched]   Install LaunchAgent (daily, weekly, monthly, on-login)
  --daemon-uninstall         Unload and remove background scan LaunchAgent
  --daemon-status            Show background daemon status and recent logs
  --alert                    Trigger native macOS notification on critical findings
  --no-color                 Disable ANSI terminal color output
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

▶ Secrets Audit Checks
----------------------------------------------------------------------
  [FAIL]  SEC-01      Plaintext API Keys in Shell Profiles
        ↳ Plaintext secrets found in shell profiles (4): .zshrc:6 (H1_API_TOKEN=***)
  [WARN]  SEC-02      Exposed .env Configuration Files
        ↳ World-readable .env secret files found (5): ~/Documents/Projects/.env (644)
  [PASS]  SEC-10      Insecure PATH Directories
        ↳ No world-writable directories or current working directory (.) in PATH.
  [PASS]  SEC-11      Cloud Credentials File Permissions
        ↳ Cloud and API credential stores possess restrictive file permissions.

▶ Persistence Audit Checks
----------------------------------------------------------------------
  [PASS]  PERS-01     User & System LaunchAgents
        ↳ All LaunchAgents reviewed and validated.
  [WARN]  PERS-02     System LaunchDaemons Review
        ↳ Broken LaunchDaemons pointing to non-existent binaries detected.
  [PASS]  PERS-10     Periodic Maintenance Scripts
        ↳ No unauthorized or custom periodic maintenance scripts found.

======================================================================
                     EXECUTIVE AUDIT SUMMARY
======================================================================

  Hardening Index: [████████████████████████░░░░░░]  82.0% (GOOD / ACCEPTABLE)

  Total Checks Audited:    50
  Passed Checks:           38
  Warnings:                8
  Failed Checks:           4
  Score Points Earned:     285.0 / 345.0
```

---

## 🔍 Audit Categories & 50 Rules

`macharden` inspects **50 security controls** mapped to authoritative benchmarks:

### 1. 🛡️ OS Hardening (`hardening` - 17 Controls)
| Check ID | Control Title | CIS Benchmark | NIST 800-53 | MITRE ATT&CK | Weight |
|:---|:---|:---:|:---:|:---:|:---:|
| `HARD-01` | System Integrity Protection (SIP) | CIS 5.1.2 | SI-7 | T1562.001 | 10 |
| `HARD-02` | FileVault 2 Full Disk Encryption | CIS 2.5.1 | SC-28 | T1552.001 | 10 |
| `HARD-03` | Gatekeeper Code Verification | CIS 5.2.1 | CM-6 | T1204.002 | 10 |
| `HARD-04` | Screen Saver Lock & Delay | CIS 2.3.1 | AC-11 | T1056.002 | 7 |
| `HARD-05` | Guest Account Restrictions | CIS 5.7 | AC-2 | T1078.003 | 6 |
| `HARD-06` | Automatic Software Updates | CIS 1.2 | SI-2 | T1190 | 6 |
| `HARD-07` | Sharing Services Attack Surface | CIS 2.2.1 | AC-3 | T1021.002 | 7 |
| `HARD-08` | Firmware Password / Recovery Lock | CIS 2.5.2 | IA-2 | T1542.001 | 8 |
| `HARD-09` | Secure Boot & Authenticated Root | CIS 5.1.1 | SI-7 | T1542.001 | 8 |
| `HARD-10` | Automatic Login Disabled | CIS 5.8 | IA-2 | T1078.003 | 6 |
| `HARD-11` | Bluetooth File Sharing | CIS 2.1.2 | AC-18 | T1011 | 5 |
| `HARD-12` | Home Directory Permissions (`$HOME` 700) | CIS 5.1.4 | AC-6 | T1083 | 6 |
| `HARD-13` | Network Time Synchronization (NTP) | CIS 1.1 | AU-8 | T1070.006 | 5 |
| `HARD-14` | Built-in Malware Protection (XProtect) | CIS 2.4.1 | SI-3 | T1562.001 | 6 |
| `HARD-15` | USB Restricted Mode | CIS 2.4.4 | MP-7 | T1091 | 5 |
| `HARD-16` | Apple Diagnostic & Telemetry Sharing | CIS 2.6.1 | AU-12 | T1020 | 4 |
| `HARD-17` | AirDrop Discoverability Mode | CIS 2.1.1 | AC-18 | T1011 | 6 |

### 2. 🌐 Network Security (`network` - 12 Controls)
| Check ID | Control Title | CIS Benchmark | NIST 800-53 | MITRE ATT&CK | Weight |
|:---|:---|:---:|:---:|:---:|:---:|
| `NET-01` | Application Firewall Global State | CIS 2.4.2 | SC-7 | T1562.004 | 8 |
| `NET-02` | Firewall Stealth Mode | CIS 2.4.3 | SC-7 | T1046 | 5 |
| `NET-03` | Firewall Exception Interpreters | CIS 2.4.2 | CM-7 | T1059.006 | 8 |
| `NET-04` | BPF Packet Capture Rights (`/dev/bpf*`) | CIS 5.1.5 | AC-6 | T1040 | 7 |
| `NET-05` | Hosts File Loopback Integrity | CIS 5.1.3 | SC-20 | T1565.001 | 9 |
| `NET-06` | Listening Wildcard Services (`0.0.0.0`) | CIS 2.2.2 | SC-7 | T1043 | 6 |
| `NET-07` | AirDrop Service Radio State | CIS 2.1.1 | AC-18 | T1011 | 6 |
| `NET-08` | Internet Sharing & NAT Services | CIS 2.2.3 | AC-4 | T1090 | 7 |
| `NET-09` | Application Firewall Logging Mode | CIS 2.4.2 | AU-2 | T1562.004 | 4 |
| `NET-10` | IP Forwarding Subsystem | CIS 2.2.4 | SC-7 | T1090 | 7 |
| `NET-11` | Promiscuous Network Interfaces | CIS 2.4.5 | AU-12 | T1040 | 6 |
| `NET-12` | Wi-Fi Open Network Auto-Join | CIS 2.1.3 | AC-18 | T1040 | 6 |

### 3. 🔑 Secrets & Privacy (`secrets` - 11 Controls)
| Check ID | Control Title | CIS Benchmark | NIST 800-53 | MITRE ATT&CK | Weight |
|:---|:---|:---:|:---:|:---:|:---:|
| `SEC-01` | Plaintext API Keys in Shell Profiles | CIS 5.1.6 | IA-5 | T1552.001 | 9 |
| `SEC-02` | Exposed `.env` Configuration Files | CIS 5.1.7 | SC-28 | T1552.001 | 6 |
| `SEC-03` | Keychain Inactivity Lock Timeout | CIS 2.3.2 | AC-11 | T1555.001 | 5 |
| `SEC-04` | Kernel Crash Core Dumps (`kern.coredump`) | CIS 5.5 | SC-28 | T1005 | 5 |
| `SEC-05` | SSH Key & Config Permissions | CIS 5.1.8 | AC-6 | T1552.004 | 7 |
| `SEC-06` | Unencrypted SSH Private Keys | CIS 5.1.9 | IA-5 | T1552.004 | 8 |
| `SEC-07` | Secrets in Interactive Shell History | CIS 5.1.10 | IA-5 | T1552.003 | 7 |
| `SEC-08` | SSH Daemon Configuration Hardening | CIS 5.2.2 | AC-3 | T1021.004 | 7 |
| `SEC-09` | Suspicious History Symlink Redirects | CIS 5.1.11 | SI-4 | T1070.003 | 5 |
| `SEC-10` | Insecure & World-Writable `$PATH` Dirs | CIS 5.1.12 | CM-6 | T1574.007 | 7 |
| `SEC-11` | Cloud & API Credentials Permissions | CIS 5.1.13 | AC-6 | T1552.001 | 8 |

### 4. ⚙️ Persistence & Integrity (`persistence` - 10 Controls)
| Check ID | Control Title | CIS Benchmark | NIST 800-53 | MITRE ATT&CK | Weight |
|:---|:---|:---:|:---:|:---:|:---:|
| `PERS-01` | User & System LaunchAgents | CIS 5.3.1 | CM-6 | T1543.001 | 7 |
| `PERS-02` | System LaunchDaemons Review | CIS 5.3.2 | CM-6 | T1543.004 | 7 |
| `PERS-03` | Scheduled Cron Jobs Inspection | CIS 5.3.3 | CM-6 | T1053.003 | 6 |
| `PERS-04` | macOS Login Items Persistence | CIS 5.3.4 | CM-6 | T1547.015 | 5 |
| `PERS-05` | SSH `authorized_keys` Backdoor Audit | CIS 5.3.5 | AC-3 | T1098.004 | 7 |
| `PERS-06` | Sudoers `NOPASSWD` Privilege Escalation | CIS 5.4 | AC-6 | T1548.003 | 8 |
| `PERS-07` | Privileged Helper Tools Integrity | CIS 5.3.6 | SI-7 | T1543.004 | 6 |
| `PERS-08` | CUPS Printer Sharing Service | CIS 2.2.5 | CM-7 | T1021 | 5 |
| `PERS-09` | Sudo Ticket Inactivity Timeout | CIS 5.4.1 | AC-11 | T1548.003 | 5 |
| `PERS-10` | Periodic Maintenance Scripts (`/etc/periodic`) | CIS 5.3.7 | SI-4 | T1053.003 | 7 |

---

## 📁 Project Structure

```
macharden/
├── bin/
│   └── macharden                  # Unified executable CLI entrypoint
├── lib/
│   ├── audit_hardening.sh         # 17 macOS system & kernel hardening checks
│   ├── audit_network.sh           # 12 network & packet sniffing checks
│   ├── audit_secrets.sh           # 11 secret leak, cloud credential & PATH checks
│   ├── audit_persistence.sh       # 10 persistence & launchd integrity checks
│   ├── compliance.sh              # CIS, NIST, and MITRE posture calculation
│   ├── diff.sh                    # Historical baseline drift & regression engine
│   ├── engine.sh                  # Check registration, weighted formula & execution
│   ├── i18n.sh                    # Localization runtime (English & Turkish)
│   ├── monitor.sh                 # Background LaunchAgent daemon & alerting
│   ├── remediate.sh               # Remediation playbook, dry-run & undo engine
│   ├── report.sh                  # Terminal & Markdown report generators
│   ├── report_html.sh             # Liquid Glass single-file HTML5 dashboard
│   ├── report_sarif.sh            # OASIS SARIF v2.1.0 generator (GitHub Code Scanning)
│   └── ui.sh                      # ANSI terminal styling, score bars & executive boxes
├── data/
│   ├── compliance_mappings.json   # 50 controls mapped to CIS, NIST, MITRE & docs
│   └── locales/
│       └── tr.json                # Authentic Turkish cybersecurity translations
├── completions/
│   ├── macharden.zsh              # Native Zsh completion definition
│   └── macharden.bash             # Native Bash completion definition
├── docs/
│   └── macharden.1                # UNIX manual page (groff man format)
├── launchd/
│   └── com.macharden.daemon.plist # Launchd template for recurring audits
├── tests/
│   ├── test_runner.sh             # Master test harness
│   ├── test_checks.sh             # 301 unit tests & report syntax verifiers
│   └── test_mocks.sh              # Mocked system checks execution
├── .github/
│   └── workflows/ci.yml           # Cross-platform GitHub Actions CI pipeline
├── Makefile                       # Unified build, test, lint, and install targets
├── LICENSE                        # MIT License
└── SECURITY.md                    # Vulnerability reporting & security policy
```

---

## 🧪 Quality Assurance & Supply Chain Integrity

`macharden` maintains an exhaustive automated test suite verified across macOS and Ubuntu runners:

| Gate / Verification | Standard & Implementation | Status |
|:---|:---|:---:|
| **Shell Syntax Guarantee** | 100% pass across all 36 scripts validated with `zsh -n` and `bash -n` | **Passing (36/36)** |
| **Automated Unit Tests** | 301 unit tests covering engine scoring, parsers, and report generators | **Passing (301/301)** |
| **Mock System Tests** | Isolated mocked checks validating real audit logic without altering host | **Passing (8/8)** |
| **JSON & SARIF Validation** | Strict schema validation with `python3 -m json.tool` and SARIF 2.1.0 specification | **Verified** |
| **Embedded JS Syntax** | All in-browser dashboard scripts validated with `node -c` | **Verified** |
| **Zero External Links** | Single-file HTML dashboard contains zero CDN links, remote scripts, or web fonts | **Zero CDN** |

```bash
# Run full verification suite:
make test
```

---

## 🔐 Cryptographic Identity & Author

**macharden** is researched and developed by Sevban Dönmez for enterprise endpoint defense, defensive telemetry auditing, and system security research.

```text
Author          : Sevban Dönmez (@jankesec)
Role            : Senior Cyber Security Consultant · Red Team & Offensive Security Researcher
Research Portal : https://jankesec.com
GitHub          : https://github.com/jankesec
PGP Fingerprint : FF0A 7D83 6751 CCE3 F9CC F574 FCF8 39FB 7F00 4626
GPG Key ID      : 5FDB257F4AAE8C3F
```

---

## ⚠️ Disclaimer

This tool is designed and distributed **exclusively for authorized security audits, endpoint hardening, defensive posture assessment, and academic research**. Applying automated remediation commands may alter system settings, firewall configurations, and service availability. Review generated remediation scripts before applying them in production environments. The author assumes no liability for unintended configuration changes or service disruption.

## 📜 License

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for complete terms.

<p align="center">
  <a href="https://www.buymeacoffee.com/sevbandonmez">
    <img src="https://img.shields.io/badge/Buy%20Me%20a%20Coffee-sevbandonmez-FFDD00?style=for-the-badge&logo=buymeacoffee&logoColor=black" alt="Buy Me A Coffee">
  </a>
</p>
