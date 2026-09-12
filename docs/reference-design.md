# Reference-driven design

macharden uses three complementary upstream ideas without treating any single
project as a drop-in policy:

- **NIST macOS Security Compliance Project (mSCP):** structured rules,
  framework provenance, tailored baselines, and organization-defined values
  (ODVs). macharden profiles use this model for settings whose correct value
  depends on the organization or threat model.
- **Lynis:** agentless auditing, stable check IDs, lightweight profiles,
  explicit suggestions, and an engine that remains useful without installation.
- **drduh macOS Security and Privacy Guide:** threat-model awareness, operator
  education, and explicit attention to usability and privacy tradeoffs.

## Safety contract

Every remediation must be typed:

- `[EXEC]` is eligible for interactive execution and generated shell playbooks.
- `[GUIDE]` is displayed as manual guidance and is never executed.
- Missing or unknown types fail closed and are excluded from executable output.

Checks must not propose an executable change when detection is ambiguous.
User-impacting or organization-defined settings should default to neutral advice
until a profile selects a policy. The login Keychain timeout is the reference
implementation of this rule.

## Source snapshots reviewed

- usnistgov/macos_security commit `c1e6cf9c41d518d0456ab6a7f12a1a4d1f227715`
- CISOfy/lynis commit `cd2c72ff101627bdf4b468950bb601581d02ce60`
- drduh/macOS-Security-and-Privacy-Guide commit `8741ed7ab5f920c8d1092eaa4a997a218d3c7821`

These are review anchors, not claims that every upstream rule has been imported.
Future control additions should record the upstream rule ID and revision used,
the local detection behavior, expected false positives, remediation risk, and a
negative-control test.
