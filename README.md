# 🛡️ macharden

<p align="center">
  <strong>Enterprise-Grade macOS Security Hardening, Baseline Drift & Audit Engine</strong><br>
  <em>Zero dependencies • Pure native Zsh/Bash • 50 CIS/NIST security controls • OASIS SARIF v2.1.0 • Liquid Glass HTML5</em>
</p>

<p align="center">
  <a href="https://github.com/jankesec/macharden/actions/workflows/ci.yml"><img src="https://github.com/jankesec/macharden/actions/workflows/ci.yml/badge.svg" alt="CI Status"></a>
  <a href="https://github.com/jankesec/macharden/releases/latest"><img src="https://img.shields.io/github/v/release/jankesec/macharden?color=blue&logo=github" alt="Latest Release"></a>
  <a href="#-license"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
  <a href="https://apple.com/macos"><img src="https://img.shields.io/badge/Platform-macOS%2012%2B%20%7C%20Apple%20Silicon%20%26%20Intel-black.svg?logo=apple&logoColor=white" alt="Platform: macOS"></a>
  <a href="#"><img src="https://img.shields.io/badge/Shell-Zsh%20%2F%20Bash-orange.svg" alt="Shell: Zsh / Bash"></a>
  <a href="#-audit-categories--50-security-rules"><img src="https://img.shields.io/badge/Audits-50%20Security%20Rules-purple.svg" alt="Audit Checks"></a>
  <a href="#-regulatory-compliance-mappings"><img src="https://img.shields.io/badge/Compliance-CIS%20%7C%20NIST%20%7C%20MITRE-darkgreen.svg" alt="Compliance"></a>
  <a href="#"><img src="https://img.shields.io/badge/Dependencies-Zero%20(Pure%20Native)-success.svg" alt="Dependencies"></a>
</p>

---

## 🎬 Live Terminal Demo

<p align="center">
  <img src="assets/demo.gif" alt="macharden live terminal execution demo" width="95%">
</p>
<p align="center"><em>Real-time audit execution of macharden on macOS: evaluating system controls, calculating the Hardening Index, displaying category posture breakdowns, and exporting multi-format security reports.</em></p>

---

## 📖 Overview

**macharden** is an enterprise-grade security audit, posture assessment, and automated hardening scanner engineered specifically for macOS (macOS 12 Monterey through macOS 15 Sequoia and macOS 26/27+, natively supporting both Apple Silicon and Intel architectures).

Unlike generic Unix scanners that treat macOS as a generic BSD derivative, **macharden** deeply inspects Apple's proprietary security subsystems:
- **System Integrity Protection (SIP)** & Authenticated Root (`csrutil`)
- **FileVault 2 XTS-AES disk encryption** (`fdesetup`)
- **Gatekeeper code signing and notarization** assessments (`spctl`)
- **Application Firewall** configuration, stealth mode & interpreter exceptions (`socketfilterfw`)
- **Keychain inactivity lock timeouts** & core dump restrictions
- **BPF raw packet capture permissions** (`/dev/bpf*` and `access_bpf` group)
- **LaunchAgents & LaunchDaemons** binary integrity & signature verification
- **Secrets scanning**: Plaintext API tokens in shell startup profiles (`~/.zshrc`, `~/.bashrc`), shell history (`.zsh_history`), exposed `.env` files, and cloud credential stores (`~/.aws/credentials`, `~/.kube/config`, `~/.docker/config.json`)
- **Privilege escalation & persistence**: Insecure `$PATH` hijacking vectors, sudoers `NOPASSWD` entries, login items, cron jobs, periodic scripts, and SSH `authorized_keys` backdoors

---

## ✨ Key Capabilities

| Capability | Description |
|:---|:---|
| ⚡ **Zero Dependencies** | Written in pure, native **Zsh/Bash**. Requires no Homebrew, Python libraries, Ruby, Gems, or Node.js runtimes. |
| 🎯 **50 Audited Controls** | Comprehensive security coverage across 4 domains: System Hardening, Network, Secrets, and Persistence. |
| 📊 **Hardening Index (0–100%)** | Objective, mathematically weighted scoring formula with letter grades (`A+` to `F`) and category-level posture bars. |
| 📉 **Baseline Drift & Diff Engine** | Historical security tracking (`--diff <baseline.json>`). Detects regressions and security posture decay between scans. |
| 🚪 **CI/CD Quality Gate** | Seamless DevSecOps integration via `--fail-on-regression` (**exit code 2**) and `--min-score <N>` (**exit code 1**). |
| 🛡️ **OASIS SARIF v2.1.0** | Native integration with GitHub Advanced Security (Code Scanning tab), GitLab SAST, DefectDojo, and SIEM pipelines. |
| 💎 **Liquid Glass HTML5 Dashboard** | Standalone, single-file interactive dashboard with zero external CDN dependencies, search, filters, and Dark/Light modes. |
| 🌐 **Bilingual (EN / TR)** | Complete native English and Turkish language support across Terminal, HTML dashboard, Markdown reports, and SARIF tags. |
| 🔧 **Automated & Safe Remediation** | Interactive remediation (`--fix`), standalone script generation (`--generate-fix`), dry-run preview (`--dry-run`), and automated rollback (`--undo`). |
| 📜 **Regulatory Compliance** | Direct control mapping to **CIS Apple macOS Benchmark**, **NIST SP 800-53 Rev 5**, and **MITRE ATT&CK Matrix for macOS**. |

---

## 💎 Liquid Glass HTML5 Dashboard

Generate an interactive, single-file HTML5 security dashboard with **zero external CDN links, zero web fonts, and zero tracking**:

```bash
macharden -f html -o report.html && open report.html
```

<p align="center">
  <img src="assets/dashboard.png" alt="macharden Liquid Glass Interactive HTML5 Dashboard" width="95%">
</p>

### Dashboard Features:
* **Interactive Filtering**: Filter findings in real time by Domain (*Hardening, Network, Secrets, Persistence*), Status (*Pass, Warn, Fail*), Severity (*Critical, High, Medium, Low*), or Regulatory Framework (*CIS, NIST, MITRE*).
* **Keyboard Shortcuts**:
  * `/` : Instant search bar focus
  * `L` : Instant language toggle (**English ⇄ Turkish**) without page reload
  * `T` : Theme toggle (**Dark Glass ⇄ Light Mode**)
  * `Esc` : Close modals / clear search
* **Remediation Playbook Modal**: In-browser interactive drawer displaying the exact shell commands needed to remediate findings, with one-click copy and script download.
* **Export Actions**: Export directly from the browser to **Markdown**, **JSON**, **OASIS SARIF**, or **Print-optimized PDF**.

---

## ⚖️ Feature Comparison

| Feature / Capability | **`macharden`** | `Lynis` | `mSCP` (macOS Compliance) | `drduh Guide` |
|:---|:---:|:---:|:---:|:---:|
| **macOS Native Architecture Focus** | **Yes (100% Native)** | Partial (Generic BSD) | Yes | Yes |
| **Zero External Dependencies** | **Yes (Pure Zsh/Bash)** | Yes (POSIX) | No (Python/Ruby) | Manual |
| **50 Audited Security Controls** | **Yes (50 Rules)** | ~30 (macOS subset) | Variable (SCAP) | Static List |
| **Objective Hardening Index (0–100%)** | **Yes (Weighted)** | Yes (Index) | No (Pass/Fail) | No |
| **Baseline Drift & Diff Engine (`--diff`)** | **Yes (JSON Diff)** | Commercial Only | No | No |
| **CI/CD Security Gate (`--fail-on-regression`)** | **Yes (Exit Code 2)**| No | No | No |
| **OASIS SARIF v2.1.0 Export (`-f sarif`)** | **Yes (GitHub Code Scanning)** | No | No | No |
| **Liquid Glass Dark Mode HTML Dashboard** | **Yes (Standalone)** | No | No | No |
| **Bilingual Localization (EN / TR)** | **Yes (Live Toggle)**| Partial | English only | English only |
| **Interactive Remediation (`--fix`)** | **Yes (Guided)** | No | No | No |
| **Standalone Fix Script Generator (`--generate-fix`)** | **Yes (Executable)** | No | Puppet/Chef only | Manual |
| **Non-Destructive Safe Mode (`--dry-run` & `--undo`)** | **Yes** | No | No | Manual |
| **Regulatory Mappings (CIS, NIST, MITRE)** | **Yes (All 50 Rules)** | Partial | CIS only | No |

---

## 🚀 Quick Start

### 1. One-Liner Quick Scan (Direct Execution)

Run an immediate, read-only security audit in your terminal without cloning:

```bash
curl -fsSL https://raw.githubusercontent.com/jankesec/macharden/main/bin/macharden | zsh
```

### 2. Clone & Run

```bash
# Clone repository
git clone https://github.com/jankesec/macharden.git
cd macharden

# Execute full 50-control security audit
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

*(Installs binary to `/usr/local/bin` or `~/.local/bin`, completions to Zsh/Bash site-functions, and manual page to `share/man/man1/macharden.1`)*

---

## 📈 Baseline Drift & CI/CD Security Gates

Prevent security regressions across developer laptops and macOS CI runners with historical baseline tracking:

```bash
# 1. Establish an initial baseline snapshot on a hardened system:
macharden -f json -o baseline.json

# 2. Run future scans and inspect drift deltas:
macharden --diff baseline.json

# 3. Enforce CI/CD security gate (fails with exit code 2 if security degrades):
macharden --diff baseline.json --fail-on-regression
```

### Executive Drift Terminal Output:
```text
======================================================================
                  BASELINE DRIFT & SECURITY DIFF
======================================================================
  Baseline Scan : 2026-09-01 10:00:00 UTC (Host: macos-workstation)
  Current Scan  : 2026-09-12 12:00:00 UTC (Host: macos-workstation)
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

### GitHub Actions CI/CD Integration Workflow

Add `macharden` to your repository's `.github/workflows/security.yml` to automatically audit macOS runner environments and upload findings to the GitHub Security tab:

```yaml
name: macOS Security Hardening Audit

on:
  push:
    branches: [ main ]
  schedule:
    - cron: '0 0 * * 1'  # Weekly scan

jobs:
  audit:
    name: Audit macOS Security Posture
    runs-on: macos-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Install macharden
        run: |
          git clone https://github.com/jankesec/macharden.git ~/.macharden-tool
          echo "$HOME/.macharden-tool/bin" >> $GITHUB_PATH

      - name: Run macharden Audit Scan
        run: |
          macharden -f sarif -o macharden-results.sarif -q || true

      - name: Upload SARIF to GitHub Code Scanning
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: macharden-results.sarif
          category: macharden-macos
```

---

## 📊 Multi-Format Reporting

Generate rich, purpose-built reports for security engineers, executive leadership, and automated pipelines:

```bash
# Liquid Glass HTML5 Dashboard (zero CDN dependencies, bilingual with 'L' key):
macharden -f html -o report.html && open report.html

# OASIS SARIF v2.1.0 for GitHub Code Scanning / Advanced Security:
macharden -f sarif -o report.sarif

# GitHub-flavored Markdown for pull requests and issue trackers:
macharden -f markdown -o report.md

# Machine-readable JSON for SIEM / Splunk / Elastic ingestion:
macharden -f json -o report.json
```

---

## 💻 CLI Command Reference

```text
macharden - macOS Security Hardening & Audit Scanner (v1.3.0)

Usage:
  macharden [options]

Core Options:
  -h, --help                 Display usage information and exit
  -v, --version              Print version information (v1.3.0)
  -c, --category <name>      Run category: hardening, network, secrets, persistence, all
  -f, --format <format>      Output format: term, markdown, json, html, sarif (default: term)
  -o, --output <file>        Save audit report to file (auto-detects format from extension)
  -q, --quiet                Minimal output, display executive summary only
  -l, --lang <en|tr>         Interface language (English or Turkish; default: en)
  --no-color                 Disable ANSI terminal color output

Baseline & Quality Gates:
  --diff <baseline.json>     Compare audit against historical baseline snapshot
  --fail-on-regression       Exit with code 2 if security posture has regressed
  --min-score <0-100>        Exit with code 1 if Hardening Index is below threshold
  --fail-on-warn             Treat warnings as failures in exit status

Remediation & Safety:
  --fix                      Interactively prompt and apply remediation fixes
  --dry-run                  Preview remediation commands without executing them
  --undo                     Rollback previous automated remediation actions
  --generate-fix [file]      Generate automated remediation shell script without applying

Filtering & Continuous Monitoring:
  --skip-test <id>[,id...]   Skip specific check IDs (e.g. --skip-test HARD-08,PERS-04)
  --profile <file>           Load skip-test configurations from profile
  --compliance <framework>   Filter report by regulatory framework (cis, nist, mitre, all)
  --daemon-install [sched]   Install background LaunchAgent (daily, weekly, monthly, on-login)
  --daemon-uninstall         Unload and remove background scan LaunchAgent
  --daemon-status            Inspect background daemon status and recent logs
  --alert                    Trigger native macOS notification on critical findings
```

---

## 🔍 Audit Categories & 50 Security Rules

`macharden` evaluates **50 security controls** mapped to authoritative benchmarks:

### 1. 🛡️ System Hardening (`hardening` - 17 Controls)
| Check ID | Control Title | CIS Benchmark | NIST 800-53 | MITRE ATT&CK | Weight |
|:---|:---|:---:|:---:|:---:|:---:|
| `HARD-01` | System Integrity Protection (SIP) | CIS 5.1.2 | SI-7 | T1562.001 | 10 |
| `HARD-02` | FileVault 2 Full Disk Encryption | CIS 2.5.1 | SC-28 | T1552.001 | 10 |
| `HARD-03` | Gatekeeper Code Assessment Verification | CIS 5.2.1 | CM-6 | T1204.002 | 10 |
| `HARD-04` | Screen Saver Lock & Delay | CIS 2.3.1 | AC-11 | T1056.002 | 7 |
| `HARD-05` | Guest Account Status | CIS 5.7 | AC-2 | T1078.003 | 6 |
| `HARD-06` | Automatic Software Updates | CIS 1.2 | SI-2 | T1190 | 6 |
| `HARD-07` | Remote Sharing Services Attack Surface | CIS 2.2.1 | AC-3 | T1021.002 | 7 |
| `HARD-08` | Firmware Password / Recovery Lock | CIS 2.5.2 | IA-2 | T1542.001 | 8 |
| `HARD-09` | Secure Boot & Authenticated Root | CIS 5.1.1 | SI-7 | T1542.001 | 8 |
| `HARD-10` | Automatic Login Disabled | CIS 5.8 | IA-2 | T1078.003 | 6 |
| `HARD-11` | Bluetooth File Sharing Exposure | CIS 2.1.2 | AC-18 | T1011 | 5 |
| `HARD-12` | Home Directory Permissions (`$HOME` 700) | CIS 5.1.4 | AC-6 | T1083 | 6 |
| `HARD-13` | Network Time Synchronization (NTP) | CIS 1.1 | AU-8 | T1070.006 | 5 |
| `HARD-14` | Built-in Malware Protection (XProtect/MRT) | CIS 2.4.1 | SI-3 | T1562.001 | 6 |
| `HARD-15` | USB Restricted Mode | CIS 2.4.4 | MP-7 | T1091 | 5 |
| `HARD-16` | Apple Diagnostic & Telemetry Sharing | CIS 2.6.1 | AU-12 | T1020 | 4 |
| `HARD-17` | AirDrop Discoverability Exposure | CIS 2.1.1 | AC-18 | T1011 | 6 |

### 2. 🌐 Network & Perimeter Security (`network` - 12 Controls)
| Check ID | Control Title | CIS Benchmark | NIST 800-53 | MITRE ATT&CK | Weight |
|:---|:---|:---:|:---:|:---:|:---:|
| `NET-01` | Application Firewall Global State | CIS 2.4.2 | SC-7 | T1562.004 | 8 |
| `NET-02` | Firewall Stealth Mode | CIS 2.4.3 | SC-7 | T1046 | 5 |
| `NET-03` | Dangerous Firewall Interpreter Exceptions | CIS 2.4.2 | CM-7 | T1059.006 | 8 |
| `NET-04` | BPF Packet Capture Permissions (`/dev/bpf*`) | CIS 5.1.5 | AC-6 | T1040 | 7 |
| `NET-05` | `/etc/hosts` Loopback Integrity | CIS 5.1.3 | SC-20 | T1565.001 | 9 |
| `NET-06` | Listening Wildcard TCP Services (`0.0.0.0`) | CIS 2.2.2 | SC-7 | T1043 | 6 |
| `NET-07` | AirDrop Radio Service State | CIS 2.1.1 | AC-18 | T1011 | 6 |
| `NET-08` | Internet Sharing & NAT Daemons | CIS 2.2.3 | AC-4 | T1090 | 7 |
| `NET-09` | Application Firewall Logging Mode | CIS 2.4.2 | AU-2 | T1562.004 | 4 |
| `NET-10` | IP Forwarding Routing Subsystem | CIS 2.2.4 | SC-7 | T1090 | 7 |
| `NET-11` | Promiscuous Network Interfaces | CIS 2.4.5 | AU-12 | T1040 | 6 |
| `NET-12` | Wi-Fi Open Network Auto-Join | CIS 2.1.3 | AC-18 | T1040 | 6 |

### 3. 🔑 Secrets, Keys & Credentials (`secrets` - 11 Controls)
| Check ID | Control Title | CIS Benchmark | NIST 800-53 | MITRE ATT&CK | Weight |
|:---|:---|:---:|:---:|:---:|:---:|
| `SEC-01` | Plaintext API Keys in Shell Profiles | CIS 5.1.6 | IA-5 | T1552.001 | 9 |
| `SEC-02` | Exposed World-Readable `.env` Files | CIS 5.1.7 | SC-28 | T1552.001 | 6 |
| `SEC-03` | Keychain Inactivity Lock Timeout | CIS 2.3.2 | AC-11 | T1555.001 | 5 |
| `SEC-04` | Kernel Crash Core Dumps (`kern.coredump`) | CIS 5.5 | SC-28 | T1005 | 5 |
| `SEC-05` | SSH Keys and Config File Permissions | CIS 5.1.8 | AC-6 | T1552.004 | 7 |
| `SEC-06` | Unencrypted SSH Private Keys | CIS 5.1.9 | IA-5 | T1552.004 | 8 |
| `SEC-07` | Secrets Leaked in Shell History Files | CIS 5.1.10 | IA-5 | T1552.003 | 7 |
| `SEC-08` | SSH Daemon Configuration Hardening | CIS 5.2.2 | AC-3 | T1021.004 | 7 |
| `SEC-09` | Suspicious Shell History Symlink Targets | CIS 5.1.11 | SI-4 | T1070.003 | 5 |
| `SEC-10` | Insecure & World-Writable `$PATH` Directories | CIS 5.1.12 | CM-6 | T1574.007 | 7 |
| `SEC-11` | Cloud & API Credentials Permissions (`.aws`, `.kube`, `.docker`) | CIS 5.1.13 | AC-6 | T1552.001 | 8 |

### 4. ⚙️ Persistence & Daemons (`persistence` - 10 Controls)
| Check ID | Control Title | CIS Benchmark | NIST 800-53 | MITRE ATT&CK | Weight |
|:---|:---|:---:|:---:|:---:|:---:|
| `PERS-01` | User & System LaunchAgents Integrity | CIS 5.3.1 | CM-6 | T1543.001 | 7 |
| `PERS-02` | System LaunchDaemons Review & Signature | CIS 5.3.2 | CM-6 | T1543.004 | 7 |
| `PERS-03` | Scheduled Cron Jobs Inspection | CIS 5.3.3 | CM-6 | T1053.003 | 6 |
| `PERS-04` | macOS Login Items Persistence | CIS 5.3.4 | CM-6 | T1547.015 | 5 |
| `PERS-05` | SSH `authorized_keys` Backdoor Audit | CIS 5.3.5 | AC-3 | T1098.004 | 7 |
| `PERS-06` | Sudoers `NOPASSWD` Privilege Escalation | CIS 5.4 | AC-6 | T1548.003 | 8 |
| `PERS-07` | Privileged Helper Tools Integrity | CIS 5.3.6 | SI-7 | T1543.004 | 6 |
| `PERS-08` | CUPS Printer Sharing Remote Vector | CIS 2.2.5 | CM-7 | T1021 | 5 |
| `PERS-09` | Sudo Authentication Ticket Timeout | CIS 5.4.1 | AC-11 | T1548.003 | 5 |
| `PERS-10` | Periodic Maintenance Scripts (`/etc/periodic`) | CIS 5.3.7 | SI-4 | T1053.003 | 7 |

---

## 📁 Repository Structure

```
macharden/
├── bin/
│   └── macharden                  # Unified CLI executable & scanner entrypoint
├── lib/
│   ├── audit_hardening.sh         # 17 macOS system & kernel hardening checks
│   ├── audit_network.sh           # 12 network, socket & packet capture checks
│   ├── audit_secrets.sh           # 11 secret leak, cloud credential & PATH checks
│   ├── audit_persistence.sh       # 10 persistence, launchd & cron checks
│   ├── compliance.sh              # CIS, NIST, and MITRE posture calculators
│   ├── diff.sh                    # Historical baseline drift & regression engine
│   ├── engine.sh                  # Weighted scoring formula & check registry
│   ├── i18n.sh                    # Localization runtime (English & Turkish)
│   ├── monitor.sh                 # Continuous LaunchAgent daemon & alerting
│   ├── remediate.sh               # Remediation playbook, dry-run & rollback engine
│   ├── report.sh                  # Terminal & Markdown executive report generators
│   ├── report_html.sh             # Liquid Glass single-file HTML5 dashboard
│   ├── report_sarif.sh            # OASIS SARIF v2.1.0 generator (GitHub Code Scanning)
│   └── ui.sh                      # ANSI terminal engine, progress bars & score boxes
├── data/
│   ├── compliance_mappings.json   # 50 controls mapped to CIS, NIST, MITRE & docs
│   └── locales/
│       └── tr.json                # Authentic Turkish cybersecurity terminology
├── assets/
│   ├── demo.gif                   # Animated terminal demo recording (vhs)
│   └── dashboard.png              # High-resolution HTML5 dashboard preview
├── completions/
│   ├── macharden.zsh              # Native Zsh completion definition
│   └── macharden.bash             # Native Bash completion definition
├── docs/
│   └── macharden.1                # Standard UNIX manual page (groff man format)
├── launchd/
│   └── com.macharden.daemon.plist # Launchd template for background audits
├── tests/
│   ├── test_runner.sh             # Master test suite runner
│   ├── test_checks.sh             # 301 unit tests, schema verifiers & CLI tests
│   └── test_mocks.sh              # Mocked system checks validation
├── .github/
│   └── workflows/ci.yml           # Cross-platform GitHub Actions CI pipeline
├── Makefile                       # Unified build, test, lint, and install targets
├── LICENSE                        # MIT License
└── SECURITY.md                    # Vulnerability reporting & responsible disclosure policy
```

---

## 🧪 Quality Assurance & CI Matrix

`macharden` is verified continuously on every pull request and commit across dual-platform GitHub Actions runners:

| Test Gate / Verification | Runner Platform | Standard & Tooling | Result |
|:---|:---|:---|:---:|
| **Cross-Platform Syntax Validation** | macOS 14/15 & Ubuntu 24.04 | All 36 shell scripts validated with `zsh -n` and `bash -n` | **36 / 36 Passing** |
| **Static Shell Analysis** | macOS 14/15 & Ubuntu 24.04 | ShellCheck linting across binary, libraries, and tests | **0 Errors** |
| **Automated Unit Tests** | macOS 14/15 & Ubuntu 24.04 | 301 unit tests covering engine scoring, parsers, and reports | **301 / 301 Passing** |
| **Mocked System Audit Logic** | macOS 14/15 & Ubuntu 24.04 | Mocked system checks verifying real audit branch behavior | **8 / 8 Passing** |
| **JSON & SARIF Validation** | macOS 14/15 & Ubuntu 24.04 | Schema validation via `python3 -m json.tool` & SARIF 2.1.0 spec | **Verified** |
| **Embedded In-Browser JavaScript** | macOS 14/15 & Ubuntu 24.04 | Client-side dashboard scripts validated with `node -c` | **Verified** |
| **Air-Gapped Privacy Invariant** | macOS 14/15 & Ubuntu 24.04 | Zero external CDN links, zero web fonts, zero tracking | **Verified (0 links)** |

```bash
# Execute local test suite:
make test
```

---

## 🔐 Cryptographic Identity & Verification

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

This tool is designed and distributed **exclusively for authorized security audits, endpoint hardening, defensive posture assessment, and academic research**. Applying automated remediation commands may alter system preferences, firewall configurations, and background services. Always review generated remediation scripts before applying them in mission-critical production environments. The author assumes no liability for unintended configuration changes or service disruption.

---

## 📜 License

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for complete terms.

<p align="center">
  <a href="https://www.buymeacoffee.com/sevbandonmez">
    <img src="https://img.shields.io/badge/Buy%20Me%20a%20Coffee-sevbandonmez-FFDD00?style=for-the-badge&logo=buymeacoffee&logoColor=black" alt="Buy Me A Coffee">
  </a>
</p>
