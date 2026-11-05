# Changelog

All notable changes to macharden are documented here. Releases follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- Checks no longer report `PASS` when they could not observe the state. They report `INFO` and say
  why (the Hardening Index ignores `INFO`, so scores can move by a few points):
  - PERS-04 (login items) can only be read with administrator access or a permission prompt, so it
    is now an `INFO` review pointer and no longer runs `osascript` or `sfltool`.
  - HARD-07 (sharing services) now reads listening sockets with `netstat`, which works without
    administrator access. Before, it could not see Remote Login, Screen Sharing or File Sharing
    and reported `PASS` on every Mac.
  - HARD-06, NET-02, NET-06, PERS-02 and SEC-05 report `INFO` when settings, firewall state,
    listeners, LaunchDaemons or SSH permissions could not be read.
- A check that records no result is reported as `WARN` instead of `PASS`.

### Added

- Scenario tests (`tests/scenarios/`, Phase 4 of the test runner): each scenario runs one check on
  only the evidence it is given. A coverage ratchet and a blind-run test keep new checks from
  reporting `PASS` without evidence.

## [1.5.0] - 2026-11-05

### Added

- `docs/CHECKS.md`, generated from `data/compliance_mappings.json` and the check
  registry (`make docs`); a unit test keeps it current.
- `make demo` regenerates `assets/demo.gif`, `assets/dashboard.png` and
  `assets/social-preview.png` from one synthetic data set.

### Changed

- The README is shorter and states only what is verified: install paths that work, the
  Python 3 requirement of the HTML, SARIF and `--diff` features, and the dashboard's real
  exports. The hand-written check tables moved to the generated reference.
- The demo fixture builds its 54 results from the real registry and renderers, and the
  drift demo no longer prints the real host name or clock.

### Fixed

- `make install` links work: `bin/macharden` resolves its real location through symlinks.
- Piping `bin/macharden` into a shell no longer derives `lib/` from the working
  directory; it stops and lists the supported install methods. Missing support files
  get the same message.
- `--min-score` and `--fail-on-warn` are accepted by the parser; they were documented
  but rejected as unknown options.
- JSON output without `python3` is valid JSON again.
- HTML, SARIF and `--diff` stop with a clear message when `python3` is unavailable.
- Terminal layout stays aligned when macharden runs without a UTF-8 locale (launchd,
  cron, minimal containers).
- The test suite no longer depends on the shell's locale or on zsh `echo` rewriting
  escape sequences.
- The HTML dashboard stays readable in the light theme (the active total box, the
  category bars and mid-range category scores), and the Turkish category cards fit a
  1200 px window instead of running past its edge.
- The user guide and the man page describe the exit codes the command really returns
  (`2` is used only by `--fail-on-regression`).

## [1.4.0] - 2026-09-12

### Added

- Adaptive terminal presentation for narrow, standard, and wide viewports.
- Profile-controlled Keychain policy with explicit organization-defined values.
- Deterministic, privacy-safe demo generation using synthetic host data only.
- A complete user guide and a current architecture and provenance reference.

### Changed

- Keychain timeout guidance is neutral unless a profile explicitly selects a
  policy, preventing an audit recommendation from causing recurring prompts.
- Remediation handling now permits only typed `[EXEC]` actions to run or enter
  generated playbooks; `[GUIDE]` and unknown actions fail closed.
- Terminal, Markdown, JSON, HTML, and SARIF output share clearer evidence and
  presentation behavior.
- CI uses pinned current actions and applies strict ShellCheck validation to the
  Bash integration while retaining native Zsh syntax validation.
- The README animation was rebuilt at higher fidelity from synthetic fixtures.

### Security and privacy

- Secret-related findings avoid exposing detected values in output.
- Public demo assets no longer depend on data collected from the generating Mac.
- Documentation now identifies report metadata that operators should sanitize
  before public sharing.

[Unreleased]: https://github.com/jankesec/macharden/compare/v1.5.0...HEAD
[1.5.0]: https://github.com/jankesec/macharden/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/jankesec/macharden/compare/v1.3.0...v1.4.0
