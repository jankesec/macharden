# macharden user guide

This guide takes an operator from a first read-only audit to tailored profiles,
reports, remediation review, drift detection, and scheduled scans.

## Before you begin

macharden is intended for Macs you own or are authorized to assess. A normal
audit reads local security configuration and does not change it. Options such as
`--fix`, generated remediation scripts, and daemon installation do change local
state and should be reviewed before use.

### Requirements

- macOS 12 or later
- Zsh
- Python 3 only when generating the interactive HTML report
- administrator access only for remediations that require `sudo`

The terminal, Markdown, JSON, and SARIF audit workflows use native shell and
macOS tools. If a protected setting cannot be read, macharden should return a
neutral or review result rather than requesting a password during a normal scan.

## Install

Clone the repository so that you can inspect the code and receive updates:

```bash
git clone https://github.com/jankesec/macharden.git
cd macharden
./bin/macharden --version
```

Run directly from the checkout or install the command, completions, and manual:

```bash
make install
macharden --version
man macharden
```

When `/usr/local` is not writable, the Makefile uses the corresponding paths
under `~/.local`. Ensure `~/.local/bin` is in `PATH` when using that layout.

## Run the first audit

Start with a read-only terminal scan:

```bash
./bin/macharden
```

For a smaller review, select a category or specific controls:

```bash
./bin/macharden --category hardening
./bin/macharden --check HARD-01,HARD-02,SEC-03
./bin/macharden --lang tr
```

Use `--no-color` for logs and terminals that do not support ANSI colors.

## Understand results

| Status | Interpretation | Score effect |
|---|---|---:|
| `PASS` | Expected state was observed. | Full weight |
| `WARN` | Partial compliance or analyst review required. | Half weight |
| `FAIL` | A defined control failure was observed. | No earned weight |
| `INFO` | Inventory or insufficient evidence. | Neutral |
| `SUGG` | Advice without a selected policy. | Neutral |

The Hardening Index is a weighted posture indicator, not a certification. Read
the finding evidence and consider the Mac's role before changing a setting.

## Tailor a profile

Copy the provided profile and edit the copy:

```bash
cp examples/macharden.prf ./workstation.prf
./bin/macharden --profile ./workstation.prf
```

Example:

```ini
profile-name=Developer Workstation
machine-role=workstation

keychain-timeout=none
keychain-lock-on-sleep=no

skip-test=HARD-08
```

`keychain-timeout=none` explicitly retains normal login-Keychain behavior. A
numeric value from 60 through 86400 selects a maximum timeout in seconds. This
setting is guidance-only: macharden does not silently impose a Keychain timeout.

Profiles can be supplied with `--profile`. Unless `--no-profile` is used,
macharden also looks for `~/.macharden/profile` and `macharden.prf`.

## Generate reports

```bash
./bin/macharden --format markdown --output report.md
./bin/macharden --format json --output report.json
./bin/macharden --format html --output report.html
./bin/macharden --format sarif --output report.sarif
```

HTML reports are standalone and can be opened locally:

```bash
open report.html
```

### Report privacy

Reports may include the hostname, audit username, macOS version and build,
configuration evidence, failed controls, and remediation text. Treat report
files as sensitive. Review and sanitize them before attaching them to public
issues, chat messages, or support requests. macharden does not upload reports
automatically.

## Review remediation safely

Preview eligible actions first:

```bash
./bin/macharden --fix --dry-run
```

Generate a playbook for review without executing it:

```bash
./bin/macharden --generate-fix fix_hardening.sh
less fix_hardening.sh
```

Only `[EXEC]` entries can become executable actions. `[GUIDE]` entries remain
manual instructions. Untyped remediation is excluded. After reviewing scope and
backups, use interactive remediation only on an authorized Mac:

```bash
./bin/macharden --fix
```

macharden stores remediation backups under `~/.macharden/backups/`. To run the
latest available rollback:

```bash
./bin/macharden --undo
```

Rollback support reduces risk but does not guarantee that every macOS setting
or third-party component can be restored. Keep an independent backup.

## Track baseline drift

Create a JSON baseline from a known and reviewed state:

```bash
./bin/macharden --format json --output baseline.json
```

Compare a later scan:

```bash
./bin/macharden --diff baseline.json
./bin/macharden --diff baseline.json --fail-on-regression
```

CI gates can also require a minimum score or reject warnings:

```bash
./bin/macharden --min-score 85
./bin/macharden --fail-on-warn
```

Relevant exit codes are:

- `0`: command completed and the configured gate passed;
- `1`: findings, threshold failure, or invalid invocation;
- `2`: regression, permission/remediation failure, or interruption.

## Scheduled audits

Install a per-user LaunchAgent:

```bash
./bin/macharden --daemon-install weekly
./bin/macharden --daemon-status
```

Supported schedules are `daily`, `weekly`, `monthly`, and `on-login`. Logs are
stored under `~/.macharden/logs/`. Remove the LaunchAgent with:

```bash
./bin/macharden --daemon-uninstall
```

Existing audit logs are preserved when the daemon is removed.

## Troubleshooting

### A check returns INFO

The detector may not have enough permission or the underlying command may not
exist on that macOS version. Run the individual check, read its evidence, and do
not treat missing evidence as a pass:

```bash
./bin/macharden --check CHECK-ID --no-color
```

### Repeated Keychain password prompts

Do not select a Keychain timeout unless the policy is intentional. Confirm that
the profile contains:

```ini
keychain-timeout=none
keychain-lock-on-sleep=no
```

The `SEC-03` check is advisory without an explicit policy and will not apply a
Keychain change automatically.

### HTML generation fails

Confirm that Python 3 is available:

```bash
python3 --version
```

Use Markdown or JSON when Python 3 is unavailable.

### Verify the checkout

Run the complete project validation suite:

```bash
make test
make lint
```

For option details, use `./bin/macharden --help` or `man macharden`.

## Uninstall

Remove installed command links, completions, and the manual page:

```bash
make uninstall
```

This does not remove saved reports, profiles, logs, or remediation backups.
Review and remove those user-owned files separately if they are no longer needed.
history. Review those files separately before deleting them.
