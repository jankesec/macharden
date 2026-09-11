#!/bin/zsh
# ==============================================================================
# macharden - lib/report_html.sh
# Modern, Interactive, Zero-Dependency HTML5 Report Generator
# ==============================================================================

# Ensure record_result and report dependencies if sourced standalone
if ! typeset -f report_json >/dev/null 2>&1; then
    local _script_dir="${0:A:h}"
    if [[ -f "$_script_dir/report.sh" ]]; then
        source "$_script_dir/report.sh"
    fi
fi

# Generate modern standalone interactive HTML report
# Usage: report_html [output_file]
report_html() {
    local output_file="${1:-}"
    local version="${MACHAR_VERSION:-1.0.0}"

    # Ensure Hardening Index is calculated
    if typeset -f calculate_hardening_index >/dev/null 2>&1; then
        calculate_hardening_index
    fi

    # Retrieve structured JSON data via report_json
    local json_data=""
    if typeset -f report_json >/dev/null 2>&1; then
        json_data=$(report_json -)
    fi

    # Fallback to python3 environment check
    if ! command -v python3 >/dev/null 2>&1; then
        echo "Error: python3 is required for HTML report generation." >&2
        return 1
    fi

    # Execute Python generator with JSON payload passed via environment variable
    AUDIT_JSON="$json_data" AUDIT_OUTPUT_FILE="$output_file" python3 - << 'PYEOF'
import os
import sys
import json
import html

raw_json = os.environ.get('AUDIT_JSON', '{}')
output_file = os.environ.get('AUDIT_OUTPUT_FILE', '')

try:
    data = json.loads(raw_json)
except Exception as e:
    sys.stderr.write(f"Error parsing audit JSON data: {e}\n")
    sys.exit(1)

scanner = data.get('scanner', {})
system = data.get('system', {})
summary = data.get('summary', {})
checks = data.get('checks', [])

# Extract summary metrics
score = float(summary.get('hardening_index', 0.0))
rating = summary.get('rating', 'UNKNOWN')
total_checks = int(summary.get('total_checks', len(checks)))
passed_checks = int(summary.get('passed', 0))
warn_checks = int(summary.get('warnings', 0))
fail_checks = int(summary.get('failed', 0))
info_checks = int(summary.get('info', 0))
sugg_checks = int(summary.get('suggestions', 0))
earned_points = float(summary.get('earned_points', 0.0))
total_points = float(summary.get('total_possible_points', 0.0))

# Percentage helpers
pass_pct = round((passed_checks / total_checks * 100.0) if total_checks > 0 else 0, 1)
warn_pct = round((warn_checks / total_checks * 100.0) if total_checks > 0 else 0, 1)
fail_pct = round((fail_checks / total_checks * 100.0) if total_checks > 0 else 0, 1)

# Gauge math: circumference of radius 72 is 2 * pi * 72 = 452.389
circumference = 452.39
gauge_offset = round(circumference * (1.0 - max(0.0, min(100.0, score)) / 100.0), 2)

# Theme accent determination based on score
if score >= 85:
    score_grade = "excellent"
    score_color = "#10b981"
    score_grad_start = "#10b981"
    score_grad_end = "#06b6d4"
elif score >= 70:
    score_grade = "good"
    score_color = "#38bdf8"
    score_grad_start = "#38bdf8"
    score_grad_end = "#10b981"
elif score >= 50:
    score_grade = "fair"
    score_color = "#f59e0b"
    score_grad_start = "#f59e0b"
    score_grad_end = "#fbbf24"
else:
    score_grade = "critical"
    score_color = "#ef4444"
    score_grad_start = "#ef4444"
    score_grad_end = "#dc2626"

# Categories count aggregation
# Standard categories: All, Hardening, Network, Secrets, Persistence, plus any dynamically found
cat_counts = {
    "all": total_checks,
    "hardening": 0,
    "network": 0,
    "secrets": 0,
    "persistence": 0
}

# Collect all dynamic categories found in checks
for c in checks:
    cat_raw = str(c.get('category', '')).strip().lower()
    if cat_raw:
        cat_counts[cat_raw] = cat_counts.get(cat_raw, 0) + 1

# List of ordered categories for tabs
ordered_categories = ["all", "hardening", "network", "secrets", "persistence"]
for c in checks:
    cat_raw = str(c.get('category', '')).strip().lower()
    if cat_raw and cat_raw not in ordered_categories:
        ordered_categories.append(cat_raw)

# Count remediable actions
remediable_checks = [c for c in checks if c.get('status') in ['FAIL', 'WARN'] and c.get('remediation')]
remediable_count = len(remediable_checks)

# Build HTML string
doc = []
doc.append("<!DOCTYPE html>")
doc.append("<html lang=\"en\">")
doc.append("<head>")
doc.append("  <meta charset=\"UTF-8\" />")
doc.append("  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />")
doc.append(f"  <title>macharden Security Audit Report — {html.escape(system.get('hostname', 'macOS'))}</title>")
doc.append("  <style>")
doc.append("""
:root {
  --bg-base: #0a0e17;
  --bg-surface: #0f172a;
  --bg-card: rgba(17, 24, 39, 0.75);
  --bg-card-hover: rgba(24, 34, 58, 0.85);
  --bg-terminal: #070a12;
  --border-subtle: rgba(255, 255, 255, 0.08);
  --border-accent: rgba(6, 182, 212, 0.3);
  --border-focus: #06b6d4;

  --text-main: #f8fafc;
  --text-muted: #94a3b8;
  --text-dim: #64748b;

  --color-cyan: #06b6d4;
  --color-cyan-glow: rgba(6, 182, 212, 0.25);
  --color-pass: #10b981;
  --color-pass-glow: rgba(16, 185, 129, 0.2);
  --color-pass-bg: rgba(16, 185, 129, 0.12);
  --color-pass-border: rgba(16, 185, 129, 0.35);

  --color-warn: #f59e0b;
  --color-warn-glow: rgba(245, 158, 11, 0.2);
  --color-warn-bg: rgba(245, 158, 11, 0.12);
  --color-warn-border: rgba(245, 158, 11, 0.35);

  --color-fail: #ef4444;
  --color-fail-glow: rgba(239, 68, 68, 0.25);
  --color-fail-bg: rgba(239, 68, 68, 0.12);
  --color-fail-border: rgba(239, 68, 68, 0.35);

  --color-info: #0ea5e9;
  --color-info-bg: rgba(14, 165, 233, 0.12);
  --color-info-border: rgba(14, 165, 233, 0.35);

  --color-sugg: #a855f7;
  --color-sugg-bg: rgba(168, 85, 247, 0.12);
  --color-sugg-border: rgba(168, 85, 247, 0.35);

  --font-sans: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  --font-mono: "SF Mono", "Fira Code", Menlo, Monaco, Consolas, monospace;
}

* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

body {
  background-color: var(--bg-base);
  background-image:
    radial-gradient(at 0% 0%, rgba(6, 182, 212, 0.08) 0px, transparent 45%),
    radial-gradient(at 100% 0%, rgba(139, 92, 246, 0.07) 0px, transparent 45%),
    radial-gradient(at 50% 100%, rgba(16, 185, 129, 0.05) 0px, transparent 50%);
  background-attachment: fixed;
  color: var(--text-main);
  font-family: var(--font-sans);
  min-height: 100vh;
  line-height: 1.5;
  -webkit-font-smoothing: antialiased;
}

.container {
  max-width: 1280px;
  margin: 0 auto;
  padding: 24px 20px 60px 20px;
}

/* Header */
.app-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 20px 24px;
  background: var(--bg-card);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
  border: 1px solid var(--border-subtle);
  border-radius: 16px;
  margin-bottom: 24px;
  box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.4);
}

.brand {
  display: flex;
  align-items: center;
  gap: 16px;
}

.brand-icon {
  width: 44px;
  height: 44px;
  border-radius: 12px;
  background: linear-gradient(135deg, rgba(6, 182, 212, 0.2), rgba(16, 185, 129, 0.2));
  border: 1px solid var(--border-accent);
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--color-cyan);
  box-shadow: 0 0 16px var(--color-cyan-glow);
}

.brand-title {
  font-size: 1.4rem;
  font-weight: 700;
  letter-spacing: -0.02em;
  color: #ffffff;
  display: flex;
  align-items: center;
  gap: 8px;
}

.brand-tag {
  font-size: 0.72rem;
  font-weight: 600;
  padding: 2px 8px;
  border-radius: 6px;
  background: rgba(6, 182, 212, 0.15);
  color: var(--color-cyan);
  border: 1px solid rgba(6, 182, 212, 0.3);
}

.brand-sub {
  font-size: 0.85rem;
  color: var(--text-muted);
}

.header-actions {
  display: flex;
  align-items: center;
  gap: 10px;
}

.btn-header {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  background: rgba(255, 255, 255, 0.05);
  border: 1px solid var(--border-subtle);
  color: var(--text-main);
  padding: 8px 14px;
  border-radius: 8px;
  font-size: 0.82rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s ease;
  font-family: inherit;
  text-decoration: none;
}

.btn-header:hover {
  background: rgba(255, 255, 255, 0.1);
  border-color: rgba(255, 255, 255, 0.2);
  transform: translateY(-1px);
}

.btn-header svg {
  width: 16px;
  height: 16px;
}

/* Executive Summary Layout */
.exec-summary {
  display: grid;
  grid-template-columns: 340px 1fr;
  gap: 20px;
  margin-bottom: 24px;
}

@media (max-width: 900px) {
  .exec-summary {
    grid-template-columns: 1fr;
  }
}

.card {
  background: var(--bg-card);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
  border: 1px solid var(--border-subtle);
  border-radius: 16px;
  padding: 24px;
  box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.35);
  position: relative;
  overflow: hidden;
}

.card-title {
  font-size: 0.85rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--text-muted);
  margin-bottom: 18px;
  display: flex;
  align-items: center;
  gap: 8px;
}

.card-title svg {
  width: 16px;
  height: 16px;
  color: var(--color-cyan);
}

/* Gauge Chart */
.gauge-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
}

.gauge-wrap {
  position: relative;
  width: 180px;
  height: 180px;
  margin: 10px auto 16px auto;
}

.gauge-svg {
  width: 100%;
  height: 100%;
  transform: rotate(-90deg);
}

.gauge-bg {
  fill: none;
  stroke: rgba(255, 255, 255, 0.06);
  stroke-width: 12;
}

.gauge-ring {
  fill: none;
  stroke-width: 12;
  stroke-linecap: round;
  transition: stroke-dashoffset 1.4s cubic-bezier(0.16, 1, 0.3, 1);
}

.gauge-content {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  pointer-events: none;
}

.gauge-score {
  font-size: 2.3rem;
  font-weight: 800;
  letter-spacing: -0.03em;
  color: #ffffff;
  line-height: 1.1;
}

.gauge-badge {
  display: inline-block;
  font-size: 0.68rem;
  font-weight: 700;
  letter-spacing: 0.04em;
  padding: 3px 10px;
  border-radius: 20px;
  margin-top: 4px;
  text-transform: uppercase;
}

.rating-excellent {
  background: var(--color-pass-bg);
  color: var(--color-pass);
  border: 1px solid var(--color-pass-border);
}

.rating-good {
  background: rgba(56, 189, 248, 0.15);
  color: #38bdf8;
  border: 1px solid rgba(56, 189, 248, 0.35);
}

.rating-fair {
  background: var(--color-warn-bg);
  color: var(--color-warn);
  border: 1px solid var(--color-warn-border);
}

.rating-critical {
  background: var(--color-fail-bg);
  color: var(--color-fail);
  border: 1px solid var(--color-fail-border);
}

.gauge-points {
  font-size: 0.82rem;
  color: var(--text-muted);
  margin-top: 6px;
}

.gauge-points strong {
  color: #ffffff;
}

/* System Metadata Grid */
.meta-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 16px;
}

@media (max-width: 600px) {
  .meta-grid {
    grid-template-columns: 1fr;
  }
}

.meta-item {
  background: rgba(255, 255, 255, 0.02);
  border: 1px solid rgba(255, 255, 255, 0.05);
  border-radius: 10px;
  padding: 12px 14px;
  display: flex;
  align-items: flex-start;
  gap: 12px;
}

.meta-icon {
  width: 34px;
  height: 34px;
  border-radius: 8px;
  background: rgba(6, 182, 212, 0.08);
  border: 1px solid rgba(6, 182, 212, 0.2);
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--color-cyan);
  flex-shrink: 0;
}

.meta-icon svg {
  width: 18px;
  height: 18px;
}

.meta-label {
  font-size: 0.7rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--text-dim);
  margin-bottom: 2px;
}

.meta-value {
  font-size: 0.85rem;
  font-weight: 500;
  color: #f1f5f9;
  word-break: break-all;
  font-family: var(--font-mono);
}

/* Counters / KPI Stat Row */
.stats-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 16px;
  margin-bottom: 24px;
}

@media (max-width: 800px) {
  .stats-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

@media (max-width: 480px) {
  .stats-grid {
    grid-template-columns: 1fr;
  }
}

.stat-card {
  background: var(--bg-card);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
  border: 1px solid var(--border-subtle);
  border-radius: 14px;
  padding: 18px 20px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  cursor: pointer;
  transition: all 0.25s cubic-bezier(0.16, 1, 0.3, 1);
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.25);
  position: relative;
  overflow: hidden;
}

.stat-card:hover {
  transform: translateY(-2px);
}

.stat-card.stat-total:hover {
  border-color: rgba(148, 163, 184, 0.5);
  box-shadow: 0 6px 24px rgba(148, 163, 184, 0.15);
}

.stat-card.stat-pass {
  border-color: rgba(16, 185, 129, 0.25);
}
.stat-card.stat-pass:hover, .stat-card.stat-pass.active {
  border-color: var(--color-pass);
  box-shadow: 0 6px 24px var(--color-pass-glow);
}

.stat-card.stat-warn {
  border-color: rgba(245, 158, 11, 0.25);
}
.stat-card.stat-warn:hover, .stat-card.stat-warn.active {
  border-color: var(--color-warn);
  box-shadow: 0 6px 24px var(--color-warn-glow);
}

.stat-card.stat-fail {
  border-color: rgba(239, 68, 68, 0.25);
}
.stat-card.stat-fail:hover, .stat-card.stat-fail.active {
  border-color: var(--color-fail);
  box-shadow: 0 6px 24px var(--color-fail-glow);
}

.stat-info {
  display: flex;
  flex-direction: column;
}

.stat-label {
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--text-muted);
}

.stat-number {
  font-size: 1.9rem;
  font-weight: 800;
  color: #ffffff;
  line-height: 1.1;
  margin: 4px 0 2px 0;
}

.stat-pass .stat-number { color: var(--color-pass); }
.stat-warn .stat-number { color: var(--color-warn); }
.stat-fail .stat-number { color: var(--color-fail); }

.stat-sub {
  font-size: 0.72rem;
  color: var(--text-dim);
}

.stat-icon {
  width: 44px;
  height: 44px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.stat-total .stat-icon { background: rgba(148, 163, 184, 0.1); color: #cbd5e1; }
.stat-pass .stat-icon  { background: var(--color-pass-bg); color: var(--color-pass); }
.stat-warn .stat-icon  { background: var(--color-warn-bg); color: var(--color-warn); }
.stat-fail .stat-icon  { background: var(--color-fail-bg); color: var(--color-fail); }

.stat-icon svg { width: 22px; height: 22px; }

/* Remediation Quick Banner */
.remed-banner {
  background: linear-gradient(135deg, rgba(245, 158, 11, 0.12), rgba(239, 68, 68, 0.08));
  border: 1px solid rgba(245, 158, 11, 0.35);
  border-radius: 14px;
  padding: 16px 20px;
  margin-bottom: 24px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.2);
}

.remed-banner-text {
  display: flex;
  align-items: center;
  gap: 14px;
}

.remed-banner-icon {
  width: 36px;
  height: 36px;
  border-radius: 8px;
  background: rgba(245, 158, 11, 0.2);
  color: var(--color-warn);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.remed-banner-icon svg { width: 20px; height: 20px; }

.remed-banner-title {
  font-size: 0.9rem;
  font-weight: 700;
  color: #ffffff;
}

.remed-banner-sub {
  font-size: 0.78rem;
  color: var(--text-muted);
}

.btn-remed-all {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  background: rgba(245, 158, 11, 0.2);
  border: 1px solid rgba(245, 158, 11, 0.4);
  color: #ffffff;
  padding: 8px 16px;
  border-radius: 8px;
  font-size: 0.8rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s ease;
  white-space: nowrap;
  font-family: inherit;
}

.btn-remed-all:hover {
  background: rgba(245, 158, 11, 0.3);
  border-color: var(--color-warn);
  transform: translateY(-1px);
}

.btn-remed-all svg { width: 16px; height: 16px; }

/* Filter & Search Toolbar */
.toolbar {
  background: var(--bg-card);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
  border: 1px solid var(--border-subtle);
  border-radius: 16px;
  padding: 16px 20px;
  margin-bottom: 24px;
  display: flex;
  flex-direction: column;
  gap: 14px;
}

/* Category Tabs Row */
.category-tabs {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
}

.tab-btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid var(--border-subtle);
  color: var(--text-muted);
  padding: 8px 14px;
  border-radius: 8px;
  font-size: 0.82rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s ease;
  font-family: inherit;
}

.tab-btn:hover {
  background: rgba(255, 255, 255, 0.08);
  color: var(--text-main);
  border-color: rgba(255, 255, 255, 0.15);
}

.tab-btn.active {
  background: rgba(6, 182, 212, 0.15);
  border-color: var(--color-cyan);
  color: #38bdf8;
  box-shadow: 0 0 12px var(--color-cyan-glow);
}

.count-badge {
  font-size: 0.7rem;
  padding: 2px 7px;
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.08);
  color: var(--text-dim);
}

.tab-btn.active .count-badge {
  background: rgba(6, 182, 212, 0.25);
  color: #ffffff;
}

/* Controls Row: Status Filters, Search, Actions */
.toolbar-controls {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  flex-wrap: wrap;
}

.status-filters {
  display: flex;
  align-items: center;
  gap: 6px;
  flex-wrap: wrap;
}

.status-btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid var(--border-subtle);
  color: var(--text-muted);
  padding: 6px 12px;
  border-radius: 6px;
  font-size: 0.78rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s ease;
  font-family: inherit;
}

.status-btn:hover {
  background: rgba(255, 255, 255, 0.08);
  color: #ffffff;
}

.status-btn.active {
  border-color: #ffffff;
  color: #ffffff;
}

.status-btn.btn-status-fail.active {
  background: var(--color-fail-bg);
  border-color: var(--color-fail);
  color: var(--color-fail);
  box-shadow: 0 0 12px var(--color-fail-glow);
}

.status-btn.btn-status-warn.active {
  background: var(--color-warn-bg);
  border-color: var(--color-warn);
  color: var(--color-warn);
  box-shadow: 0 0 12px var(--color-warn-glow);
}

.status-btn.btn-status-pass.active {
  background: var(--color-pass-bg);
  border-color: var(--color-pass);
  color: var(--color-pass);
  box-shadow: 0 0 12px var(--color-pass-glow);
}

.status-dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
}
.dot-fail { background: var(--color-fail); box-shadow: 0 0 6px var(--color-fail); }
.dot-warn { background: var(--color-warn); box-shadow: 0 0 6px var(--color-warn); }
.dot-pass { background: var(--color-pass); box-shadow: 0 0 6px var(--color-pass); }

/* Search Box */
.search-group {
  display: flex;
  align-items: center;
  gap: 12px;
  flex: 1;
  min-width: 260px;
  max-width: 440px;
}

.search-box {
  position: relative;
  width: 100%;
}

.search-icon {
  position: absolute;
  left: 12px;
  top: 50%;
  transform: translateY(-50%);
  width: 16px;
  height: 16px;
  color: var(--text-dim);
  pointer-events: none;
}

.search-input {
  width: 100%;
  background: rgba(15, 23, 42, 0.7);
  border: 1px solid var(--border-subtle);
  border-radius: 8px;
  padding: 8px 32px 8px 36px;
  font-size: 0.82rem;
  color: #ffffff;
  outline: none;
  transition: all 0.2s ease;
  font-family: inherit;
}

.search-input:focus {
  border-color: var(--border-focus);
  box-shadow: 0 0 12px var(--color-cyan-glow);
  background: rgba(15, 23, 42, 0.9);
}

.search-clear {
  position: absolute;
  right: 10px;
  top: 50%;
  transform: translateY(-50%);
  background: none;
  border: none;
  color: var(--text-dim);
  cursor: pointer;
  font-size: 1.1rem;
  padding: 0;
  display: none;
  line-height: 1;
}

.search-clear:hover {
  color: #ffffff;
}

.results-info {
  font-size: 0.76rem;
  color: var(--text-dim);
  white-space: nowrap;
}

.results-info strong {
  color: var(--text-main);
}

/* Checks List & Cards */
.checks-list {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.check-card {
  background: var(--bg-card);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
  border: 1px solid var(--border-subtle);
  border-radius: 14px;
  padding: 20px;
  transition: all 0.2s ease;
  position: relative;
  border-left-width: 4px;
}

.check-card:hover {
  background: var(--bg-card-hover);
  border-color: rgba(255, 255, 255, 0.15);
}

.check-card.status-pass { border-left-color: var(--color-pass); }
.check-card.status-warn { border-left-color: var(--color-warn); }
.check-card.status-fail { border-left-color: var(--color-fail); }
.check-card.status-info { border-left-color: var(--color-info); }
.check-card.status-sugg { border-left-color: var(--color-sugg); }

.card-header-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  flex-wrap: wrap;
  margin-bottom: 12px;
}

.card-header-left {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
}

/* Status Badges */
.badge-status {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.04em;
  padding: 4px 9px;
  border-radius: 6px;
  text-transform: uppercase;
}

.badge-status svg {
  width: 13px;
  height: 13px;
}

.badge-pass {
  background: var(--color-pass-bg);
  border: 1px solid var(--color-pass-border);
  color: var(--color-pass);
}

.badge-warn {
  background: var(--color-warn-bg);
  border: 1px solid var(--color-warn-border);
  color: var(--color-warn);
}

.badge-fail {
  background: var(--color-fail-bg);
  border: 1px solid var(--color-fail-border);
  color: var(--color-fail);
}

.badge-info {
  background: var(--color-info-bg);
  border: 1px solid var(--color-info-border);
  color: var(--color-info);
}

.badge-sugg {
  background: var(--color-sugg-bg);
  border: 1px solid var(--color-sugg-border);
  color: var(--color-sugg);
}

.check-id-chip {
  font-family: var(--font-mono);
  font-size: 0.75rem;
  font-weight: 600;
  background: rgba(255, 255, 255, 0.05);
  border: 1px solid rgba(255, 255, 255, 0.1);
  padding: 3px 8px;
  border-radius: 5px;
  color: var(--text-muted);
}

.category-chip {
  font-size: 0.72rem;
  font-weight: 600;
  background: rgba(6, 182, 212, 0.08);
  border: 1px solid rgba(6, 182, 212, 0.2);
  padding: 3px 8px;
  border-radius: 5px;
  color: var(--color-cyan);
  text-transform: capitalize;
}

.check-title {
  font-size: 0.98rem;
  font-weight: 600;
  color: #ffffff;
}

.weight-badge {
  font-size: 0.7rem;
  font-weight: 500;
  color: var(--text-dim);
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid rgba(255, 255, 255, 0.06);
  padding: 3px 8px;
  border-radius: 6px;
}

.check-details {
  font-size: 0.86rem;
  color: #cbd5e1;
  line-height: 1.55;
  margin-bottom: 12px;
}

/* Remediation Box */
.terminal-box {
  background: var(--bg-terminal);
  border: 1px solid rgba(255, 255, 255, 0.07);
  border-radius: 8px;
  overflow: hidden;
  margin-top: 10px;
}

.terminal-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 7px 12px;
  background: rgba(255, 255, 255, 0.03);
  border-bottom: 1px solid rgba(255, 255, 255, 0.05);
}

.terminal-dots {
  display: flex;
  align-items: center;
  gap: 6px;
}

.tdot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
}
.tdot-red { background: #ef4444; }
.tdot-yellow { background: #f59e0b; }
.tdot-green { background: #10b981; }

.terminal-label {
  font-size: 0.7rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--text-dim);
  margin-left: 8px;
  display: flex;
  align-items: center;
  gap: 6px;
}

.terminal-label svg {
  width: 12px;
  height: 12px;
}

.btn-copy {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  background: rgba(255, 255, 255, 0.05);
  border: 1px solid rgba(255, 255, 255, 0.1);
  color: var(--text-muted);
  padding: 4px 10px;
  border-radius: 5px;
  font-size: 0.72rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s ease;
  font-family: inherit;
}

.btn-copy:hover {
  background: rgba(255, 255, 255, 0.1);
  color: #ffffff;
  border-color: rgba(255, 255, 255, 0.2);
}

.btn-copy.copied {
  background: var(--color-pass-bg);
  border-color: var(--color-pass);
  color: var(--color-pass);
}

.btn-copy svg {
  width: 12px;
  height: 12px;
}

.terminal-body {
  padding: 10px 14px;
  font-family: var(--font-mono);
  font-size: 0.8rem;
  color: #38bdf8;
  white-space: pre-wrap;
  word-break: break-all;
  line-height: 1.45;
}

.terminal-prompt {
  color: var(--text-dim);
  user-select: none;
  margin-right: 4px;
}

/* Empty State */
.empty-state {
  display: none;
  text-align: center;
  padding: 48px 20px;
  background: var(--bg-card);
  border: 1px dashed var(--border-subtle);
  border-radius: 16px;
  margin: 20px 0;
}

.empty-icon {
  width: 48px;
  height: 48px;
  margin: 0 auto 16px auto;
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.04);
  color: var(--text-dim);
  display: flex;
  align-items: center;
  justify-content: center;
}

.empty-icon svg {
  width: 24px;
  height: 24px;
}

.empty-title {
  font-size: 1.05rem;
  font-weight: 600;
  color: #ffffff;
  margin-bottom: 6px;
}

.empty-desc {
  font-size: 0.82rem;
  color: var(--text-muted);
  max-width: 400px;
  margin: 0 auto 16px auto;
}

.btn-reset {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  background: rgba(6, 182, 212, 0.15);
  border: 1px solid var(--color-cyan);
  color: #38bdf8;
  padding: 8px 16px;
  border-radius: 8px;
  font-size: 0.8rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s ease;
  font-family: inherit;
}

.btn-reset:hover {
  background: rgba(6, 182, 212, 0.25);
  transform: translateY(-1px);
}

/* Footer */
.app-footer {
  margin-top: 40px;
  text-align: center;
  font-size: 0.78rem;
  color: var(--text-dim);
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.footer-link {
  color: var(--color-cyan);
  text-decoration: none;
}

.footer-link:hover {
  text-decoration: underline;
}

/* Print Stylesheet */
@media print {
  @page {
    margin: 1.2cm;
    size: A4 portrait;
  }

  body {
    background: #ffffff !important;
    color: #0f172a !important;
    font-size: 10pt !important;
  }

  .container {
    max-width: 100% !important;
    padding: 0 !important;
  }

  .no-print,
  .app-header .header-actions,
  .remed-banner .btn-remed-all,
  .toolbar,
  .btn-copy,
  .empty-state {
    display: none !important;
  }

  .app-header {
    background: #ffffff !important;
    border: 1px solid #cbd5e1 !important;
    box-shadow: none !important;
    padding: 12pt !important;
    margin-bottom: 12pt !important;
  }

  .brand-title {
    color: #0f172a !important;
  }

  .brand-sub {
    color: #475569 !important;
  }

  .exec-summary {
    grid-template-columns: 240px 1fr !important;
    gap: 12pt !important;
    margin-bottom: 12pt !important;
  }

  .card {
    background: #ffffff !important;
    border: 1px solid #cbd5e1 !important;
    box-shadow: none !important;
    padding: 12pt !important;
  }

  .gauge-wrap {
    width: 130px !important;
    height: 130px !important;
  }

  .gauge-score {
    color: #0f172a !important;
    font-size: 1.8rem !important;
  }

  .meta-item {
    background: #f8fafc !important;
    border: 1px solid #e2e8f0 !important;
    padding: 8pt !important;
  }

  .meta-value {
    color: #0f172a !important;
  }

  .stats-grid {
    gap: 8pt !important;
    margin-bottom: 12pt !important;
  }

  .stat-card {
    background: #ffffff !important;
    border: 1px solid #cbd5e1 !important;
    box-shadow: none !important;
    padding: 10pt !important;
  }

  .stat-number {
    font-size: 1.5rem !important;
  }

  .remed-banner {
    background: #fffbeb !important;
    border: 1px solid #f59e0b !important;
    box-shadow: none !important;
    margin-bottom: 12pt !important;
  }

  .remed-banner-title {
    color: #92400e !important;
  }

  .remed-banner-sub {
    color: #b45309 !important;
  }

  .check-card {
    display: block !important;
    background: #ffffff !important;
    border: 1px solid #cbd5e1 !important;
    box-shadow: none !important;
    page-break-inside: avoid;
    break-inside: avoid;
    margin-bottom: 10pt !important;
    padding: 12pt !important;
  }

  .check-title {
    color: #0f172a !important;
  }

  .check-details {
    color: #334155 !important;
  }

  .terminal-box {
    background: #f8fafc !important;
    border: 1px solid #cbd5e1 !important;
  }

  .terminal-body {
    color: #0f172a !important;
  }

  .terminal-header {
    background: #f1f5f9 !important;
    border-bottom: 1px solid #cbd5e1 !important;
  }

  .app-footer {
    margin-top: 16pt !important;
    color: #64748b !important;
  }
}
""")
doc.append("  </style>")
doc.append("</head>")
doc.append("<body>")
doc.append("  <div class=\"container\">")

# Header
doc.append("    <header class=\"app-header\">")
doc.append("      <div class=\"brand\">")
doc.append("        <div class=\"brand-icon\">")
doc.append("          <svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z\"/></svg>")
doc.append("        </div>")
doc.append("        <div>")
doc.append(f"          <div class=\"brand-title\">macharden <span class=\"brand-tag\">v{html.escape(scanner.get('version', '1.0.0'))}</span></div>")
doc.append("          <div class=\"brand-sub\">macOS Security Hardening & Audit Scanner</div>")
doc.append("        </div>")
doc.append("      </div>")
doc.append("      <div class=\"header-actions no-print\">")
doc.append("        <button class=\"btn-header\" onclick=\"exportAuditJSON()\" title=\"Export audit data as JSON\">")
doc.append("          <svg viewBox=\"0 0 20 20\" fill=\"currentColor\"><path fill-rule=\"evenodd\" d=\"M3 17a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm3.293-7.707a1 1 0 011.414 0L9 10.586V3a1 1 0 112 0v7.586l1.293-1.293a1 1 0 111.414 1.414l-3 3a1 1 0 01-1.414 0l-3-3a1 1 0 010-1.414z\" clip-rule=\"evenodd\"/></svg>")
doc.append("          Export JSON")
doc.append("        </button>")
doc.append("        <button class=\"btn-header\" onclick=\"window.print()\" title=\"Print or export as PDF\">")
doc.append("          <svg viewBox=\"0 0 20 20\" fill=\"currentColor\"><path fill-rule=\"evenodd\" d=\"M5 4v3H4a2 2 0 00-2 2v3a2 2 0 002 2h1v2a2 2 0 002 2h6a2 2 0 002-2v-2h1a2 2 0 002-2V9a2 2 0 00-2-2h-1V4a2 2 0 00-2-2H7a2 2 0 00-2 2zm8 0H7v3h6V4zm0 8H7v4h6v-4z\" clip-rule=\"evenodd\"/></svg>")
doc.append("          Print / PDF")
doc.append("        </button>")
doc.append("      </div>")
doc.append("    </header>")

# Executive Summary Section
doc.append("    <section class=\"exec-summary\">")

# Gauge Card
doc.append("      <div class=\"card gauge-card\">")
doc.append("        <div class=\"card-title\">")
doc.append("          <svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><circle cx=\"12\" cy=\"12\" r=\"10\"/><path d=\"M12 6v6l4 2\"/></svg>")
doc.append("          Hardening Score")
doc.append("        </div>")
doc.append("        <div class=\"gauge-wrap\">")
doc.append("          <svg viewBox=\"0 0 180 180\" class=\"gauge-svg\">")
doc.append("            <defs>")
doc.append(f"              <linearGradient id=\"gaugeGradient\" x1=\"0%\" y1=\"0%\" x2=\"100%\" y2=\"100%\">")
doc.append(f"                <stop offset=\"0%\" stop-color=\"{score_grad_start}\" />")
doc.append(f"                <stop offset=\"100%\" stop-color=\"{score_grad_end}\" />")
doc.append("              </linearGradient>")
doc.append("            </defs>")
doc.append("            <circle class=\"gauge-bg\" cx=\"90\" cy=\"90\" r=\"72\" />")
doc.append(f"            <circle class=\"gauge-ring\" id=\"gaugeRing\" cx=\"90\" cy=\"90\" r=\"72\" stroke=\"url(#gaugeGradient)\" stroke-dasharray=\"{circumference}\" stroke-dashoffset=\"{gauge_offset}\" />")
doc.append("          </svg>")
doc.append("          <div class=\"gauge-content\">")
doc.append(f"            <div class=\"gauge-score\">{score:.1f}<span style=\"font-size:1.1rem;font-weight:600\">%</span></div>")
doc.append(f"            <div class=\"gauge-badge rating-{score_grade}\">{html.escape(rating)}</div>")
doc.append("          </div>")
doc.append("        </div>")
doc.append(f"        <div class=\"gauge-points\"><strong>{earned_points:.1f}</strong> / {total_points:.1f} points earned</div>")
doc.append("      </div>")

# System Information Card
doc.append("      <div class=\"card\">")
doc.append("        <div class=\"card-title\">")
doc.append("          <svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><rect x=\"2\" y=\"2\" width=\"20\" height=\"8\" rx=\"2\" ry=\"2\"/><rect x=\"2\" y=\"14\" width=\"20\" height=\"8\" rx=\"2\" ry=\"2\"/><line x1=\"6\" y1=\"6\" x2=\"6.01\" y2=\"6\"/><line x1=\"6\" y1=\"18\" x2=\"6.01\" y2=\"18\"/></svg>")
doc.append("          System Metadata")
doc.append("        </div>")
doc.append("        <div class=\"meta-grid\">")

# Hostname
doc.append("          <div class=\"meta-item\">")
doc.append("            <div class=\"meta-icon\"><svg viewBox=\"0 0 20 20\" fill=\"currentColor\"><path fill-rule=\"evenodd\" d=\"M2 5a2 2 0 012-2h12a2 2 0 012 2v2a2 2 0 01-2 2H4a2 2 0 01-2-2V5zm14 1a1 1 0 11-2 0 1 1 0 012 0zM2 13a2 2 0 012-2h12a2 2 0 012 2v2a2 2 0 01-2 2H4a2 2 0 01-2-2v-2zm14 1a1 1 0 11-2 0 1 1 0 012 0z\" clip-rule=\"evenodd\"/></svg></div>")
doc.append("            <div>")
doc.append("              <div class=\"meta-label\">Target Hostname</div>")
doc.append(f"              <div class=\"meta-value\">{html.escape(str(system.get('hostname', 'localhost')))}</div>")
doc.append("            </div>")
doc.append("          </div>")

# User
doc.append("          <div class=\"meta-item\">")
doc.append("            <div class=\"meta-icon\"><svg viewBox=\"0 0 20 20\" fill=\"currentColor\"><path fill-rule=\"evenodd\" d=\"M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z\" clip-rule=\"evenodd\"/></svg></div>")
doc.append("            <div>")
doc.append("              <div class=\"meta-label\">Audit User</div>")
doc.append(f"              <div class=\"meta-value\">{html.escape(str(system.get('user', 'root')))}</div>")
doc.append("            </div>")
doc.append("          </div>")

# OS Version & Build
os_display = f"{system.get('os_product', 'macOS')} {system.get('os_version', '')} ({system.get('os_build', '')})".strip()
doc.append("          <div class=\"meta-item\">")
doc.append("            <div class=\"meta-icon\"><svg viewBox=\"0 0 24 24\" fill=\"currentColor\"><path d=\"M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 6.37c.62-.75 1.04-1.8 0.93-2.85-.9.04-1.99.6-2.64 1.35-.57.65-1.06 1.7-0.92 2.72.99.08 2.02-.47 2.63-1.22z\"/></svg></div>")
doc.append("            <div>")
doc.append("              <div class=\"meta-label\">Operating System</div>")
doc.append(f"              <div class=\"meta-value\">{html.escape(os_display)}</div>")
doc.append("            </div>")
doc.append("          </div>")

# Arch & Kernel
hw_display = f"{system.get('arch', 'arm64')} (Darwin {system.get('kernel', '')})".strip()
doc.append("          <div class=\"meta-item\">")
doc.append("            <div class=\"meta-icon\"><svg viewBox=\"0 0 20 20\" fill=\"currentColor\"><path fill-rule=\"evenodd\" d=\"M11.49 3.17c-.38-1.56-2.6-1.56-2.98 0a1.532 1.532 0 01-2.286.948c-1.372-.836-2.942.734-2.106 2.106.54.886.061 2.042-.947 2.287-1.561.379-1.561 2.6 0 2.978a1.532 1.532 0 01.947 2.287c-.836 1.372.734 2.942 2.106 2.106a1.532 1.532 0 012.287.947c.379 1.561 2.6 1.561 2.978 0a1.533 1.533 0 012.287-.947c1.372.836 2.942-.734 2.106-2.106a1.533 1.533 0 01.947-2.287c1.561-.379 1.561-2.6 0-2.978a1.532 1.532 0 01-.947-2.287c.836-1.372-.734-2.942-2.106-2.106a1.532 1.532 0 01-2.287-.947zM10 13a3 3 0 100-6 3 3 0 000 6z\" clip-rule=\"evenodd\"/></svg></div>")
doc.append("            <div>")
doc.append("              <div class=\"meta-label\">Hardware Architecture</div>")
doc.append(f"              <div class=\"meta-value\">{html.escape(hw_display)}</div>")
doc.append("            </div>")
doc.append("          </div>")

# Timestamp
doc.append("          <div class=\"meta-item\">")
doc.append("            <div class=\"meta-icon\"><svg viewBox=\"0 0 20 20\" fill=\"currentColor\"><path fill-rule=\"evenodd\" d=\"M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z\" clip-rule=\"evenodd\"/></svg></div>")
doc.append("            <div>")
doc.append("              <div class=\"meta-label\">Audit Timestamp</div>")
doc.append(f"              <div class=\"meta-value\">{html.escape(str(scanner.get('timestamp', '')))}</div>")
doc.append("            </div>")
doc.append("          </div>")

# Scanner Engine
engine_display = f"{scanner.get('name', 'macharden')} v{scanner.get('version', '1.0.0')}"
doc.append("          <div class=\"meta-item\">")
doc.append("            <div class=\"meta-icon\"><svg viewBox=\"0 0 20 20\" fill=\"currentColor\"><path fill-rule=\"evenodd\" d=\"M2.166 4.999A11.954 11.954 0 0010 1.944 11.954 11.954 0 0017.834 5c.11.65.166 1.32.166 2.001 0 5.225-3.34 9.67-8 11.317C5.34 16.67 2 12.225 2 7c0-.682.057-1.35.166-2.001zm11.541 3.708a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z\" clip-rule=\"evenodd\"/></svg></div>")
doc.append("            <div>")
doc.append("              <div class=\"meta-label\">Security Scanner</div>")
doc.append(f"              <div class=\"meta-value\">{html.escape(engine_display)}</div>")
doc.append("            </div>")
doc.append("          </div>")

doc.append("        </div>")
doc.append("      </div>")
doc.append("    </section>")

# KPI Stat Cards Row
doc.append("    <section class=\"stats-grid\">")

# Total Checks
doc.append("      <div class=\"stat-card stat-total\" onclick=\"filterByStatus('all')\" title=\"Click to show all checks\">")
doc.append("        <div class=\"stat-info\">")
doc.append("          <span class=\"stat-label\">Total Controls</span>")
doc.append(f"          <span class=\"stat-number\">{total_checks}</span>")
doc.append("          <span class=\"stat-sub\">Evaluated controls</span>")
doc.append("        </div>")
doc.append("        <div class=\"stat-icon\"><svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><path d=\"M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z\"/></svg></div>")
doc.append("      </div>")

# Passed Checks
doc.append("      <div class=\"stat-card stat-pass\" onclick=\"filterByStatus('PASS')\" title=\"Click to filter passed checks\">")
doc.append("        <div class=\"stat-info\">")
doc.append("          <span class=\"stat-label\">Passed</span>")
doc.append(f"          <span class=\"stat-number\">{passed_checks}</span>")
doc.append(f"          <span class=\"stat-sub\">{pass_pct}% compliance</span>")
doc.append("        </div>")
doc.append("        <div class=\"stat-icon\"><svg viewBox=\"0 0 20 20\" fill=\"currentColor\"><path fill-rule=\"evenodd\" d=\"M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z\" clip-rule=\"evenodd\"/></svg></div>")
doc.append("      </div>")

# Warnings
doc.append("      <div class=\"stat-card stat-warn\" onclick=\"filterByStatus('WARN')\" title=\"Click to filter warnings\">")
doc.append("        <div class=\"stat-info\">")
doc.append("          <span class=\"stat-label\">Warnings</span>")
doc.append(f"          <span class=\"stat-number\">{warn_checks}</span>")
doc.append(f"          <span class=\"stat-sub\">{warn_pct}% attention</span>")
doc.append("        </div>")
doc.append("        <div class=\"stat-icon\"><svg viewBox=\"0 0 20 20\" fill=\"currentColor\"><path fill-rule=\"evenodd\" d=\"M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z\" clip-rule=\"evenodd\"/></svg></div>")
doc.append("      </div>")

# Failed Checks
doc.append("      <div class=\"stat-card stat-fail\" onclick=\"filterByStatus('FAIL')\" title=\"Click to filter failed checks\">")
doc.append("        <div class=\"stat-info\">")
doc.append("          <span class=\"stat-label\">Failed</span>")
doc.append(f"          <span class=\"stat-number\">{fail_checks}</span>")
doc.append(f"          <span class=\"stat-sub\">{fail_pct}% non-compliant</span>")
doc.append("        </div>")
doc.append("        <div class=\"stat-icon\"><svg viewBox=\"0 0 20 20\" fill=\"currentColor\"><path fill-rule=\"evenodd\" d=\"M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z\" clip-rule=\"evenodd\"/></svg></div>")
doc.append("      </div>")

doc.append("    </section>")

# Remediation Banner (if remediable actions exist)
if remediable_count > 0:
    doc.append("    <div class=\"remed-banner\">")
    doc.append("      <div class=\"remed-banner-text\">")
    doc.append("        <div class=\"remed-banner-icon\"><svg viewBox=\"0 0 20 20\" fill=\"currentColor\"><path fill-rule=\"evenodd\" d=\"M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z\" clip-rule=\"evenodd\"/></svg></div>")
    doc.append("        <div>")
    doc.append(f"          <div class=\"remed-banner-title\">{remediable_count} Security Controls Require Remediation</div>")
    doc.append("          <div class=\"remed-banner-sub\">Apply suggested fixes to harden your macOS host or export an automated remediation script.</div>")
    doc.append("        </div>")
    doc.append("      </div>")
    doc.append("      <button class=\"btn-remed-all\" onclick=\"copyAllFixCommands()\" title=\"Copy all fix commands to clipboard\">")
    doc.append("        <svg viewBox=\"0 0 20 20\" fill=\"currentColor\"><path d=\"M8 3a1 1 0 011-1h2a1 1 0 110 2H9a1 1 0 01-1-1z\" /><path d=\"M6 3a2 2 0 00-2 2v11a2 2 0 002 2h8a2 2 0 002-2V5a2 2 0 00-2-2 3 3 0 01-3 3H9a3 3 0 01-3-3z\" /></svg>")
    doc.append("        <span id=\"copyAllText\">Copy All Fix Commands</span>")
    doc.append("      </button>")
    doc.append("    </div>")

# Interactive Filter & Search Toolbar
doc.append("    <section class=\"toolbar no-print\">")

# Category Tabs
doc.append("      <div class=\"category-tabs\" role=\"tablist\">")
for cat_key in ordered_categories:
    cnt = cat_counts.get(cat_key, 0)
    display_name = cat_key.capitalize() if cat_key != "all" else "All"
    active_cls = "active" if cat_key == "all" else ""
    doc.append(f"        <button class=\"tab-btn {active_cls}\" data-category=\"{cat_key}\" onclick=\"filterByCategory('{cat_key}')\" role=\"tab\">")
    doc.append(f"          {html.escape(display_name)} <span class=\"count-badge\">{cnt}</span>")
    doc.append("        </button>")
doc.append("      </div>")

# Controls Row (Status filters + Search)
doc.append("      <div class=\"toolbar-controls\">")
doc.append("        <div class=\"status-filters\">")
doc.append(f"          <button class=\"status-btn active\" data-status=\"all\" onclick=\"filterByStatus('all')\">All <span class=\"count-badge\">{total_checks}</span></button>")
doc.append(f"          <button class=\"status-btn btn-status-fail\" data-status=\"FAIL\" onclick=\"filterByStatus('FAIL')\"><span class=\"status-dot dot-fail\"></span>Fail <span class=\"count-badge\">{fail_checks}</span></button>")
doc.append(f"          <button class=\"status-btn btn-status-warn\" data-status=\"WARN\" onclick=\"filterByStatus('WARN')\"><span class=\"status-dot dot-warn\"></span>Warn <span class=\"count-badge\">{warn_checks}</span></button>")
doc.append(f"          <button class=\"status-btn btn-status-pass\" data-status=\"PASS\" onclick=\"filterByStatus('PASS')\"><span class=\"status-dot dot-pass\"></span>Pass <span class=\"count-badge\">{passed_checks}</span></button>")
if (info_checks + sugg_checks) > 0:
    doc.append(f"          <button class=\"status-btn\" data-status=\"INFO\" onclick=\"filterByStatus('INFO')\">Info/Sugg <span class=\"count-badge\">{info_checks + sugg_checks}</span></button>")
doc.append("        </div>")

# Search Input
doc.append("        <div class=\"search-group\">")
doc.append("          <div class=\"search-box\">")
doc.append("            <svg class=\"search-icon\" viewBox=\"0 0 20 20\" fill=\"currentColor\"><path fill-rule=\"evenodd\" d=\"M8 4a4 4 0 100 8 4 4 0 000-8zM2 8a6 6 0 1110.89 3.476l4.817 4.817a1 1 0 01-1.414 1.414l-4.816-4.816A6 6 0 012 8z\" clip-rule=\"evenodd\"/></svg>")
doc.append("            <input type=\"text\" id=\"searchInput\" class=\"search-input\" placeholder=\"Search by ID, title, details, or command...\" oninput=\"handleSearch()\" autocomplete=\"off\" />")
doc.append("            <button id=\"searchClear\" class=\"search-clear\" onclick=\"clearSearch()\" title=\"Clear search\">×</button>")
doc.append("          </div>")
doc.append("          <div class=\"results-info\">Showing <strong id=\"visibleCount\">" + str(total_checks) + "</strong> of " + str(total_checks) + "</div>")
doc.append("        </div>")
doc.append("      </div>")

doc.append("    </section>")

# Checks List
doc.append("    <section class=\"checks-list\" id=\"checksList\">")

for c in checks:
    cid = html.escape(str(c.get('id', '')))
    cat = html.escape(str(c.get('category', 'hardening'))).lower()
    title = html.escape(str(c.get('title', '')))
    c_status = str(c.get('status', 'INFO')).upper()
    weight = html.escape(str(c.get('weight', 5)))
    details = html.escape(str(c.get('details', '')))
    remed = str(c.get('remediation', '')).strip()

    # Search keyword string
    search_haystack = f"{cid} {cat} {title} {details} {remed}".lower()

    # Status class
    status_lower = c_status.lower()
    card_cls = f"check-card status-{status_lower}"

    # Status badge icon and label
    badge_icon = ""
    if c_status == "PASS":
        badge_icon = '<svg viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/></svg>'
    elif c_status == "WARN":
        badge_icon = '<svg viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/></svg>'
    elif c_status == "FAIL":
        badge_icon = '<svg viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"/></svg>'
    elif c_status == "INFO":
        badge_icon = '<svg viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"/></svg>'
    else:
        badge_icon = '<svg viewBox="0 0 20 20" fill="currentColor"><path d="M11 3a1 1 0 10-2 0v1a1 1 0 102 0V3zM15.657 5.757a1 1 0 00-1.414-1.414l-.707.707a1 1 0 001.414 1.414l.707-.707zM18 10a1 1 0 01-1 1h-1a1 1 0 110-2h1a1 1 0 011 1zM5.05 6.464A1 1 0 106.464 5.05l-.707-.707a1 1 0 00-1.414 1.414l.707.707zM5 10a1 1 0 01-1 1H3a1 1 0 110-2h1a1 1 0 011 1zM8 16v-1h4v1a2 2 0 11-4 0zM12 14H8a4 4 0 01-.8-7.92 4.002 4.002 0 017.6 0A4 4 0 0112 14z"/></svg>'

    doc.append(f"      <article class=\"{card_cls}\" data-id=\"{cid}\" data-category=\"{cat}\" data-status=\"{c_status}\" data-search=\"{html.escape(search_haystack)}\">")
    doc.append("        <div class=\"card-header-row\">")
    doc.append("          <div class=\"card-header-left\">")
    doc.append(f"            <span class=\"badge-status badge-{status_lower}\">{badge_icon} {c_status}</span>")
    doc.append(f"            <span class=\"check-id-chip\">{cid}</span>")
    doc.append(f"            <span class=\"category-chip\">{cat}</span>")
    doc.append(f"            <h3 class=\"check-title\">{title}</h3>")
    doc.append("          </div>")
    doc.append("          <div class=\"card-header-right\">")
    doc.append(f"            <span class=\"weight-badge\">Weight: {weight}</span>")
    doc.append("          </div>")
    doc.append("        </div>")

    # Details
    if details:
        doc.append(f"        <div class=\"check-details\">{details}</div>")

    # Remediation Command Box (if present)
    if remed:
        # JSON safe string for JS function invocation
        escaped_remed_attr = html.escape(remed, quote=True)
        escaped_remed_body = html.escape(remed)

        doc.append("        <div class=\"terminal-box\">")
        doc.append("          <div class=\"terminal-header\">")
        doc.append("            <div class=\"terminal-dots\">")
        doc.append("              <span class=\"tdot tdot-red\"></span>")
        doc.append("              <span class=\"tdot tdot-yellow\"></span>")
        doc.append("              <span class=\"tdot tdot-green\"></span>")
        doc.append("              <span class=\"terminal-label\">")
        doc.append("                <svg viewBox=\"0 0 20 20\" fill=\"currentColor\"><path fill-rule=\"evenodd\" d=\"M2 5a2 2 0 012-2h12a2 2 0 012 2v10a2 2 0 01-2 2H4a2 2 0 01-2-2V5zm3.293 1.293a1 1 0 011.414 0l3 3a1 1 0 010 1.414l-3 3a1 1 0 01-1.414-1.414L7.586 10 5.293 7.707a1 1 0 010-1.414zM11 12a1 1 0 100 2h3a1 1 0 100-2h-3z\" clip-rule=\"evenodd\"/></svg>")
        doc.append("                Remediation Fix")
        doc.append("              </span>")
        doc.append("            </div>")
        doc.append(f"            <button class=\"btn-copy\" data-cmd=\"{escaped_remed_attr}\" onclick=\"copyFixCommand(this)\" title=\"Copy remediation command to clipboard\">")
        doc.append("              <svg viewBox=\"0 0 20 20\" fill=\"currentColor\"><path d=\"M8 3a1 1 0 011-1h2a1 1 0 110 2H9a1 1 0 01-1-1z\" /><path d=\"M6 3a2 2 0 00-2 2v11a2 2 0 002 2h8a2 2 0 002-2V5a2 2 0 00-2-2 3 3 0 01-3 3H9a3 3 0 01-3-3z\" /></svg>")
        doc.append("              <span>Copy Fix Command</span>")
        doc.append("            </button>")
        doc.append("          </div>")
        doc.append(f"          <pre class=\"terminal-body\"><code><span class=\"terminal-prompt\">$</span>{escaped_remed_body}</code></pre>")
        doc.append("        </div>")

    doc.append("      </article>")

doc.append("    </section>")

# Empty State
doc.append("    <div class=\"empty-state\" id=\"emptyState\">")
doc.append("      <div class=\"empty-icon\"><svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><circle cx=\"11\" cy=\"11\" r=\"8\"/><line x1=\"21\" y1=\"21\" x2=\"16.65\" y2=\"16.65\"/></svg></div>")
doc.append("      <div class=\"empty-title\">No Security Checks Found</div>")
doc.append("      <div class=\"empty-desc\">No checks match your active category, status, and search filters. Try resetting the filters to view all audit controls.</div>")
doc.append("      <button class=\"btn-reset\" onclick=\"resetAllFilters()\">")
doc.append("        <svg viewBox=\"0 0 20 20\" fill=\"currentColor\" style=\"width:16px;height:16px\"><path fill-rule=\"evenodd\" d=\"M4 2a1 1 0 011 1v2.101a7.002 7.002 0 0111.601 2.566 1 1 0 11-1.885.666A5.002 5.002 0 005.999 7H9a1 1 0 010 2H4a1 1 0 01-1-1V3a1 1 0 011-1zm.008 9.057a1 1 0 011.276.61A5.002 5.002 0 0014.001 13H11a1 1 0 110-2h5a1 1 0 011 1v5a1 1 0 11-2 0v-2.101a7.002 7.002 0 01-11.601-2.566 1 1 0 01.61-1.276z\" clip-rule=\"evenodd\"/></svg>")
doc.append("        Reset All Filters")
doc.append("      </button>")
doc.append("    </div>")

# Footer
doc.append("    <footer class=\"app-footer\">")
doc.append("      <div>Automated Security Hardening Audit generated by <strong>macharden</strong></div>")
doc.append(f"      <div>Target Host: <code>{html.escape(system.get('hostname', 'localhost'))}</code> • Scan Time: {html.escape(scanner.get('timestamp', ''))}</div>")
doc.append("    </footer>")

doc.append("  </div>")

# Embedded JSON Payload
doc.append("  <script id=\"macharden-raw-data\" type=\"application/json\">")
doc.append(json.dumps(data, indent=2).replace("</script>", "<\\/script>"))
doc.append("  </script>")

# Client-Side Interactive Script
doc.append("  <script>")
doc.append("""
// State management
let currentCategory = 'all';
let currentStatus = 'all';
let currentQuery = '';

// Core Filter Engine
function applyFilters() {
  const cards = document.querySelectorAll('.check-card');
  let visibleCount = 0;

  cards.forEach(card => {
    const cardCat = card.getAttribute('data-category') || '';
    const cardStatus = card.getAttribute('data-status') || '';
    const cardSearch = card.getAttribute('data-search') || '';

    // Check category match
    let matchCat = (currentCategory === 'all') || (cardCat === currentCategory);

    // Check status match
    let matchStatus = (currentStatus === 'all') || (cardStatus === currentStatus);
    if (currentStatus === 'INFO' && (cardStatus === 'INFO' || cardStatus === 'SUGG')) {
      matchStatus = true;
    }

    // Check search query match
    let matchSearch = true;
    if (currentQuery.length > 0) {
      matchSearch = cardSearch.includes(currentQuery);
    }

    if (matchCat && matchStatus && matchSearch) {
      card.style.display = 'block';
      visibleCount++;
    } else {
      card.style.display = 'none';
    }
  });

  // Update visible count indicator
  const visibleEl = document.getElementById('visibleCount');
  if (visibleEl) {
    visibleEl.textContent = visibleCount;
  }

  // Handle empty state display
  const emptyState = document.getElementById('emptyState');
  if (emptyState) {
    emptyState.style.display = visibleCount === 0 ? 'block' : 'none';
  }
}

// Category filter trigger
function filterByCategory(category) {
  currentCategory = category.toLowerCase();

  // Update tab styles
  document.querySelectorAll('.tab-btn').forEach(btn => {
    if (btn.getAttribute('data-category') === currentCategory) {
      btn.classList.add('active');
    } else {
      btn.classList.remove('active');
    }
  });

  applyFilters();
}

// Status filter trigger
function filterByStatus(status) {
  currentStatus = status.toUpperCase();
  if (status.toLowerCase() === 'all') {
    currentStatus = 'all';
  }

  // Update status filter buttons
  document.querySelectorAll('.status-btn').forEach(btn => {
    const btnSt = btn.getAttribute('data-status');
    if (btnSt === currentStatus) {
      btn.classList.add('active');
    } else {
      btn.classList.remove('active');
    }
  });

  // Highlight corresponding stat card
  document.querySelectorAll('.stat-card').forEach(card => {
    card.classList.remove('active');
  });
  if (currentStatus === 'PASS') {
    document.querySelector('.stat-card.stat-pass')?.classList.add('active');
  } else if (currentStatus === 'WARN') {
    document.querySelector('.stat-card.stat-warn')?.classList.add('active');
  } else if (currentStatus === 'FAIL') {
    document.querySelector('.stat-card.stat-fail')?.classList.add('active');
  }

  applyFilters();
}

// Search input handling
function handleSearch() {
  const input = document.getElementById('searchInput');
  const clearBtn = document.getElementById('searchClear');
  if (!input) return;

  currentQuery = input.value.toLowerCase().trim();
  if (clearBtn) {
    clearBtn.style.display = currentQuery.length > 0 ? 'block' : 'none';
  }

  applyFilters();
}

function clearSearch() {
  const input = document.getElementById('searchInput');
  const clearBtn = document.getElementById('searchClear');
  if (input) {
    input.value = '';
  }
  if (clearBtn) {
    clearBtn.style.display = 'none';
  }
  currentQuery = '';
  applyFilters();
}

// Reset all filters
function resetAllFilters() {
  currentCategory = 'all';
  currentStatus = 'all';
  currentQuery = '';

  const input = document.getElementById('searchInput');
  const clearBtn = document.getElementById('searchClear');
  if (input) input.value = '';
  if (clearBtn) clearBtn.style.display = 'none';

  document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.classList.toggle('active', btn.getAttribute('data-category') === 'all');
  });

  document.querySelectorAll('.status-btn').forEach(btn => {
    btn.classList.toggle('active', btn.getAttribute('data-status') === 'all');
  });

  document.querySelectorAll('.stat-card').forEach(card => card.classList.remove('active'));

  applyFilters();
}

// Copy Fix Command
function copyFixCommand(btn) {
  const cmd = btn.getAttribute('data-cmd');
  if (!cmd) return;

  copyTextToClipboard(cmd, () => {
    const originalContent = btn.innerHTML;
    btn.innerHTML = `<svg viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/></svg> <span>Copied!</span>`;
    btn.classList.add('copied');

    setTimeout(() => {
      btn.innerHTML = originalContent;
      btn.classList.remove('copied');
    }, 2200);
  });
}

// Copy All Fix Commands
function copyAllFixCommands() {
  const cards = document.querySelectorAll('.check-card');
  const commands = [];

  cards.forEach(card => {
    const copyBtn = card.querySelector('.btn-copy');
    if (copyBtn) {
      const cid = card.getAttribute('data-id');
      const title = card.querySelector('.check-title')?.textContent || '';
      const cmd = copyBtn.getAttribute('data-cmd');
      if (cmd) {
        commands.push(`# [${cid}] ${title}\\n${cmd}\\n`);
      }
    }
  });

  if (commands.length === 0) return;

  const scriptHeader = `#!/bin/zsh\\n# macharden remediation actions\\n# Generated on: ${new Date().toISOString()}\\n\\n`;
  const fullScript = scriptHeader + commands.join('\\n');

  copyTextToClipboard(fullScript, () => {
    const textSpan = document.getElementById('copyAllText');
    if (textSpan) {
      const orig = textSpan.textContent;
      textSpan.textContent = "Copied All Fixes!";
      setTimeout(() => {
        textSpan.textContent = orig;
      }, 2200);
    }
  });
}

// Universal clipboard helper with fallback
function copyTextToClipboard(text, onSuccess) {
  if (navigator.clipboard && navigator.clipboard.writeText) {
    navigator.clipboard.writeText(text).then(onSuccess).catch(() => {
      fallbackCopy(text, onSuccess);
    });
  } else {
    fallbackCopy(text, onSuccess);
  }
}

function fallbackCopy(text, onSuccess) {
  const ta = document.createElement('textarea');
  ta.value = text;
  ta.style.position = 'fixed';
  ta.style.top = '0';
  ta.style.left = '0';
  ta.style.opacity = '0';
  document.body.appendChild(ta);
  ta.focus();
  ta.select();
  try {
    const success = document.execCommand('copy');
    if (success && onSuccess) onSuccess();
  } catch (err) {
    console.error('Copy fallback failed:', err);
  }
  document.body.removeChild(ta);
}

// Export Audit JSON
function exportAuditJSON() {
  const el = document.getElementById('macharden-raw-data');
  if (!el) return;
  const jsonStr = el.textContent.trim();
  const blob = new Blob([jsonStr], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `macharden_audit_${new Date().toISOString().slice(0, 10)}.json`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', () => {
  // Animate Donut Gauge
  const ring = document.getElementById('gaugeRing');
  if (ring) {
    const targetOffset = ring.getAttribute('stroke-dashoffset');
    ring.style.strokeDashoffset = '452.39';
    setTimeout(() => {
      ring.style.strokeDashoffset = targetOffset;
    }, 120);
  }
});
""")
doc.append("  </script>")
doc.append("</body>")
doc.append("</html>")

html_content = "\n".join(doc)

# Output handling
if output_file and output_file != "-":
    out_dir = os.path.dirname(output_file)
    if out_dir and not os.path.exists(out_dir):
        os.makedirs(out_dir, exist_ok=True)
    with open(output_file, "w", encoding="utf-8") as f:
        f.write(html_content)
else:
    sys.stdout.write(html_content + "\n")

PYEOF

    local exit_code=$?
    if (( exit_code != 0 )); then
        return $exit_code
    fi

    if [[ -n "$output_file" && "$output_file" != "-" ]]; then
        if [[ "${MACHAR_QUIET:-0}" -eq 0 ]]; then
            ui_success "HTML report generated: ${output_file}"
        fi
    fi

    return 0
}
