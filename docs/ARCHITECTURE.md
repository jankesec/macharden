# macharden architecture

This document describes the current design of macharden. It is an operational
reference, not a roadmap or a list of planned features.

## Design goals

macharden is a local-first macOS security posture tool designed to be:

- read-only during a normal audit;
- explicit and fail-closed when remediation is requested;
- useful without an agent, cloud service, or external telemetry;
- traceable from a check result to a control mapping and authoritative source;
- adaptable to personal, developer, and managed workstation baselines; and
- consistent across terminal, Markdown, JSON, HTML, and SARIF output.

It is not an MDM replacement, an EDR product, or proof that a Mac is secure.
A passing result means only that the local detector observed its expected state.

## Runtime flow

```text
CLI arguments and profile
          │
          ▼
  check registry and filters
          │
          ▼
 native macOS detectors ──────► normalized evidence
          │                         PASS / WARN / FAIL
          │                         INFO / SUGG
          ▼
 weighted scoring engine
          │
          ├────────► terminal summary
          ├────────► Markdown / JSON
          ├────────► standalone HTML
          ├────────► SARIF
          └────────► baseline drift comparison
```

`bin/macharden` owns argument parsing and orchestration. Audit modules register
stable check IDs with `lib/engine.sh`; the engine records normalized results and
calculates the Hardening Index. Report modules consume the recorded result set
without rerunning detectors.

## Check contract

Each check has a stable ID, category, title, weight, detector function, evidence
message, and optional remediation. Categories are `hardening`, `network`,
`secrets`, and `persistence`.

Detectors should:

1. use native, non-interactive commands;
2. avoid changing system state;
3. return `INFO` when state cannot be determined safely;
4. never print credential values or secret contents;
5. describe what was observed, not claim protection beyond the evidence; and
6. provide a negative-control test for security-sensitive parsing.

## Result and scoring model

Scored results use the configured check weight:

| Result | Earned weight | Meaning |
|---|---:|---|
| `PASS` | 100% | Detector observed the expected state. |
| `WARN` | 50% | Review is recommended or policy is partially met. |
| `FAIL` | 0% | Detector observed a defined control failure. |
| `INFO` | Excluded | Inventory or insufficient evidence. |
| `SUGG` | Excluded | Advisory recommendation without a selected policy. |

The Hardening Index is `earned scored weight / total scored weight × 100`.
Neutral results are visible but do not silently reduce the score. Categories
containing only neutral results display `N/A` rather than a misleading zero.

## Safety boundaries

### Audit boundary

A standard run is read-only. Checks may encounter macOS privacy or permission
boundaries; missing access must not be converted into a false failure.

### Remediation boundary

Every remediation is typed:

- `[EXEC]` may be offered interactively and included in executable playbooks.
- `[GUIDE]` is manual guidance and is never executed.
- missing or unknown types are excluded from executable output.

Generated scripts are review artifacts. The operator remains responsible for
reviewing scope, backups, user impact, and the target Mac before execution.

### Organization-defined values

Some settings do not have one universally correct value. Profiles model these
as organization-defined values (ODVs). The login Keychain timeout is the
reference case: without an explicit profile choice, macharden reports advice
instead of changing password-prompt behavior.

### Privacy boundary

macharden does not upload results. Exported reports can still contain hostname,
username, OS build, local configuration evidence, and security findings. They
must be treated as sensitive artifacts and sanitized before public sharing.

The README animation is built only from `scripts/demo_fixture.sh`. That fixture
uses deterministic synthetic identity and findings and never invokes a live
host audit.

## Profiles and policy

Profiles are parsed by `lib/engine.sh`. Unknown keys and invalid values fail
instead of being silently ignored. Supported settings currently include:

- `profile-name`
- `machine-role`
- `skip-test`
- `keychain-timeout`
- `keychain-lock-on-sleep`

Skipping a check records a neutral result so the report preserves evidence that
the control was intentionally excluded.

## Reporting and drift

Terminal output is adaptive from narrow to wide viewports. Markdown and JSON are
portable evidence formats; HTML is a standalone local dashboard; SARIF supports
code-scanning integrations. JSON baselines can be compared with `--diff` to
identify regressions without treating a new scan as historical truth.

All report formats are derived from the same result arrays. Format-specific code
must not alter status, score, remediation type, or compliance meaning.

## Reference provenance

macharden uses complementary ideas from:

- [NIST macOS Security Compliance Project](https://github.com/usnistgov/macos_security):
  structured rules, tailored baselines, ODVs, and framework provenance.
- [Lynis](https://github.com/CISOfy/lynis): agentless auditing, stable test IDs,
  profiles, and explicit suggestions.
- [macOS Security and Privacy Guide](https://github.com/drduh/macOS-Security-and-Privacy-Guide):
  threat-model awareness and usability/privacy tradeoffs.

The reviewed anchors for the current design were:

- `usnistgov/macos_security` at `c1e6cf9c41d518d0456ab6a7f12a1a4d1f227715`
- `CISOfy/lynis` at `cd2c72ff101627bdf4b468950bb601581d02ce60`
- `drduh/macOS-Security-and-Privacy-Guide` at `8741ed7ab5f920c8d1092eaa4a997a218d3c7821`

These are design references, not claims of complete coverage or source-code
inheritance. New controls should record the upstream rule or document revision,
local detector behavior, expected false positives, remediation risk, and tests.

## Validation

The repository test runner validates scoring, registry integrity, reports,
localization, remediation typing, profile parsing, drift behavior, and mocked
system checks. GitHub Actions runs the suite on macOS and Ubuntu and performs a
live read-only smoke scan on the macOS runner.
