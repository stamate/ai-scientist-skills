#!/usr/bin/env bash
# Install ai-scientist-skills and all optional enhancement plugins.
# Usage: bash scripts/install-all.sh
set -euo pipefail

echo "=== AI Scientist Skills — Full Installation ==="
echo ""

# 1. Main plugin
echo "[1/3] Installing ai-scientist-skills..."
claude install gh:stamate/ai-scientist-skills 2>/dev/null && echo "  ✓ ai-scientist-skills" || echo "  ✓ ai-scientist-skills (already installed)"

# 2. Codex plugin (panel review, code review, rescue)
echo "[2/3] Installing codex-plugin-cc..."
claude install gh:stamate/codex-plugin-cc 2>/dev/null && echo "  ✓ codex-plugin-cc" || echo "  ✓ codex-plugin-cc (already installed)"

# 3. Scientific skills (78+ databases, IMRAD writing, DOI verification)
echo "[3/3] Installing claude-scientific-skills..."
claude install gh:stamate/claude-scientific-skills 2>/dev/null && echo "  ✓ claude-scientific-skills" || echo "  ✓ claude-scientific-skills (already installed)"

echo ""

# 4. Codex CLI (needed for codex-plugin-cc)
if command -v codex &>/dev/null; then
    echo "✓ Codex CLI already installed"
else
    echo "Installing Codex CLI..."
    npm install -g @openai/codex
    echo "  ✓ Codex CLI installed — run 'codex login' to authenticate"
fi

echo ""
echo "=== Installation complete ==="
echo ""
echo "Verify with:  python3 tools/verify_setup.py"
echo "Quick start:  claude '/ai-scientist --workshop examples/ideas/i_cant_believe_its_not_better.md'"
