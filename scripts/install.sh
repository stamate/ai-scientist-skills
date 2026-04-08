#!/usr/bin/env bash
set -euo pipefail

# AI Scientist Skills — Install
# Usage: curl -fsSL https://raw.githubusercontent.com/stamate/ai-scientist-skills/main/scripts/install.sh | bash

REPO="https://github.com/stamate/ai-scientist-skills.git"

echo "=== AI Scientist Skills — Install ==="
echo ""

# 1. Check prerequisites
for cmd in uv claude; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: $cmd not found. Please install it first."
        exit 1
    fi
done

# 2. Create .venv and install Python package + all dependencies
echo "[1/4] Creating .venv and installing Python tools..."
uv venv --quiet 2>/dev/null || true
uv pip install "git+${REPO}" --quiet
echo "  .venv created with: torch, numpy, matplotlib, seaborn, transformers, etc."
echo "  CLI tools: ai-scientist-verify, ai-scientist-state, ai-scientist-config, ..."
echo "  OK"

# 3. Add and update marketplaces
echo "[2/4] Adding marketplaces..."
# Core: ai-scientist + codex + scientific skills
claude plugin marketplace add stamate/ai-scientist-skills 2>/dev/null || true
claude plugin marketplace add stamate/codex-plugin-cc 2>/dev/null || true
claude plugin marketplace add K-Dense-AI/claude-scientific-skills 2>/dev/null || true
# Extras: scientific writer, superpowers, context7, astral, code-review, claude-hud
claude plugin marketplace add K-Dense-AI/claude-scientific-writer 2>/dev/null || true
# Update all to ensure latest versions
claude plugin marketplace update stm-ai-sci 2>/dev/null || true
claude plugin marketplace update stm-codex 2>/dev/null || true
claude plugin marketplace update claude-scientific-skills 2>/dev/null || true
claude plugin marketplace update claude-scientific-writer 2>/dev/null || true
claude plugin marketplace update claude-plugins-official 2>/dev/null || true
claude plugin marketplace update astral-sh 2>/dev/null || true
claude plugin marketplace update claude-hud 2>/dev/null || true
echo "  OK"

# 4. Install plugins at project scope
echo "[3/4] Installing plugins..."
# Core
claude plugin install ai-scientist@stm-ai-sci --scope project 2>/dev/null || true
claude plugin install codex@stm-codex --scope project 2>/dev/null || true
claude plugin install scientific-skills@claude-scientific-skills --scope project 2>/dev/null || true
# Enhanced writing + citations
claude plugin install claude-scientific-writer@claude-scientific-writer --scope project 2>/dev/null || true
# Planning, parallel agents, brainstorming
claude plugin install superpowers@claude-plugins-official --scope project 2>/dev/null || true
# Library docs lookup for experiment code
claude plugin install context7@claude-plugins-official --scope project 2>/dev/null || true
# Code review (complements codex reviews)
claude plugin install code-review@claude-plugins-official --scope project 2>/dev/null || true
# Python linting and formatting (ruff/uv)
claude plugin install astral@astral-sh --scope project 2>/dev/null || true
# Status line HUD
claude plugin install claude-hud@claude-hud --scope project 2>/dev/null || true
echo "  OK"

# 5. Create CLAUDE.md if it doesn't exist
echo "[4/4] Creating CLAUDE.md..."
if [ ! -f CLAUDE.md ]; then
    cat > CLAUDE.md << 'CLAUDEMD'
# AI Scientist Skills

## Environment

This project uses `uv` with a `.venv` directory. **ALWAYS** prefix `ai-scientist-*` commands with `uv run`:

```bash
uv run ai-scientist-verify
uv run ai-scientist-device --info
uv run ai-scientist-config --config templates/bfts_config.yaml
uv run ai-scientist-state status <exp_dir>
uv run ai-scientist-search "query" --limit 10
uv run ai-scientist-metrics <file>
uv run ai-scientist-latex compile <dir>
uv run ai-scientist-pdf <file>
uv run ai-scientist-budget --config templates/bfts_config.yaml
```

**Never** run `ai-scientist-*` commands without `uv run` — they are installed in `.venv/bin/` and won't be found otherwise.

**Never** `cd` into the plugin cache directory. Always run commands from this project directory.

## Installed Plugins

- **ai-scientist** — Full research pipeline (ideation, experiment, writeup, review)
- **codex** — Codex delegation and code review
- **scientific-skills** — 134 scientific skills (databases, tools, analysis)
- **claude-scientific-writer** — Enhanced scientific writing and citations
- **superpowers** — Planning, parallel agents, brainstorming
- **context7** — Library and framework documentation lookup
- **code-review** — Code review (complements Codex reviews)
- **astral** — Python linting and formatting (ruff/uv)
- **claude-hud** — Status line display

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/stamate/ai-scientist-skills/main/scripts/install.sh | bash
```

## Run

```bash
claude '/ai-scientist --workshop examples/ideas/i_cant_believe_its_not_better.md'
```
CLAUDEMD
    echo "  Created CLAUDE.md"
else
    echo "  CLAUDE.md already exists, skipping"
fi
echo "  OK"

echo ""
echo "=== Done ==="
echo ""
echo "  Verify: uv run ai-scientist-verify"
echo "  Run:    claude '/ai-scientist'"
