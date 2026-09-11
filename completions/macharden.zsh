#compdef macharden

# ==============================================================================
# macharden - Zsh Completion Script
# Native completion definition for macOS Security Hardening & Audit Scanner
# ==============================================================================

_macharden() {
    local context state state_descr line
    typeset -A opt_args

    local -a categories
    categories=(
        'hardening:Audit system settings, Gatekeeper, SIP, FileVault, and auto updates'
        'network:Audit application firewall, stealth mode, open ports, and sharing'
        'secrets:Audit unencrypted private keys, cloud tokens, history, and dotfiles'
        'persistence:Audit LaunchDaemons, LaunchAgents, cron jobs, and login items'
        'all:Execute all security audit checks across every domain'
    )

    local -a formats
    formats=(
        'term:Colorized human-readable terminal output'
        'json:Machine-readable structured JSON format'
        'markdown:GitHub-flavored Markdown report'
        'html:Interactive responsive HTML report with score dashboard'
    )

    local -a compliance_frameworks
    compliance_frameworks=(
        'cis:Center for Internet Security Apple macOS Benchmark'
        'nist:NIST SP 800-53 / NIST Cybersecurity Framework (CSF)'
        'mitre:MITRE ATT&CK Enterprise Matrix for macOS'
    )

    local -a daemon_schedules
    daemon_schedules=(
        'daily:Run background scan every 24 hours (86,400s)'
        'weekly:Run background scan every 7 days (default)'
        'monthly:Run background scan every 30 days'
        'hourly:Run background scan every hour (3,600s)'
        'on-login:Run background scan when user logs in (RunAtLoad)'
    )

    _arguments -s -S \
        '(-h --help)'{-h,--help}'[Display help message and exit]' \
        '(-v --version)'{-v,--version}'[Print version information and exit]' \
        '(-c --category)'{-c,--category}'[Run specific category of audit checks]:category:->categories' \
        '(-f --format)'{-f,--format}'[Output report format]:format:->formats' \
        '(-o --output)'{-o,--output}'[Save audit report to specified file path]:output file:_files' \
        '(-q --quiet)'{-q,--quiet}'[Minimal output, print only final executive summary]' \
        '--fix[Interactively prompt and apply remediation fixes for failed checks]' \
        '--generate-fix[Generate automated remediation shell script without applying]::remediation script output:_files -g "*.sh"' \
        '--no-color[Disable ANSI terminal color output]' \
        '--compliance[Filter or map audit checks against security compliance frameworks]:compliance framework:->compliance' \
        '--daemon-install[Install and schedule background scan LaunchAgent]::schedule:->schedules' \
        '--daemon-uninstall[Unload and remove background scan LaunchAgent]' \
        '--daemon-status[Display background scan agent status and execution history]' \
        '--alert[Trigger native macOS notification if critical vulnerabilities or leaks found]' \
        && return 0

    case $state in
        categories)
            _describe -t categories 'audit category' categories
            ;;
        formats)
            _describe -t formats 'report format' formats
            ;;
        compliance)
            _describe -t compliance 'compliance framework' compliance_frameworks
            ;;
        schedules)
            _describe -t schedules 'daemon schedule' daemon_schedules
            ;;
    esac
}

# Support autoloading via compinit as well as direct sourcing
if [[ -o kshautoload ]]; then
    _macharden "$@"
elif [[ "$funcstack[1]" = "_macharden" ]] || [[ "$0" = "_macharden" ]]; then
    _macharden "$@"
else
    compdef _macharden macharden 2>/dev/null || true
fi
