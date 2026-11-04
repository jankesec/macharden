# Changelog

All notable changes to macharden are documented here. Releases follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

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

[1.4.0]: https://github.com/jankesec/macharden/compare/v1.3.0...v1.4.0
