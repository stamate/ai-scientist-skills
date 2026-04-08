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
echo "[1/3] Creating .venv and installing Python tools..."
uv venv --quiet 2>/dev/null || true
uv pip install "git+${REPO}" --quiet
echo "  .venv created with: torch, numpy, matplotlib, seaborn, transformers, etc."
echo "  CLI tools: ai-scientist-verify, ai-scientist-state, ai-scientist-config, ..."
echo "  OK"

# 3. Add marketplaces
echo "[2/3] Adding marketplaces..."
claude plugin marketplace add stamate/ai-scientist-skills 2>/dev/null || true
claude plugin marketplace add stamate/codex-plugin-cc 2>/dev/null || true
claude plugin marketplace add K-Dense-AI/claude-scientific-skills 2>/dev/null || true
echo "  OK"

# 4. Install plugins at project scope
echo "[3/3] Installing plugins..."
claude plugin install ai-scientist@stm-ai-sci --scope project 2>/dev/null || true
claude plugin install codex@stm-codex --scope project 2>/dev/null || true
claude plugin install scientific-skills@claude-scientific-skills --scope project 2>/dev/null || true
echo "  OK"

echo ""
echo "=== Done ==="
echo ""
echo "  Project uses uv with .venv — Claude Code auto-detects it."
echo "  All tools (ai-scientist-verify, etc.) are in .venv/bin/"
echo ""
echo "  Verify: source .venv/bin/activate && ai-scientist-verify"
echo "  Run:    claude '/ai-scientist --workshop examples/ideas/i_cant_believe_its_not_better.md'"
