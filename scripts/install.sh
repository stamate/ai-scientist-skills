#!/usr/bin/env bash
set -uo pipefail
# Note: NOT using set -e — we handle errors explicitly per step

# AI Scientist Skills — Install
# Usage: curl -fsSL https://raw.githubusercontent.com/stamate/ai-scientist-skills/main/scripts/install.sh | bash

REPO="https://github.com/stamate/ai-scientist-skills.git"
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}!${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }

echo "=== AI Scientist Skills — Install ==="
echo ""

# 1. Check prerequisites
for cmd in uv claude; do
    if ! command -v "$cmd" &>/dev/null; then
        fail "$cmd not found. Please install it first."
        exit 1
    fi
done

# 2. Create .venv and install Python tools
echo "[1/5] Python tools..."
if [ -d ".venv" ]; then
    warn ".venv exists — upgrading packages"
    uv pip install --upgrade "git+${REPO}" --quiet 2>&1 || {
        fail "Failed to upgrade packages. Check network and try again."
        exit 1
    }
else
    uv venv --quiet 2>&1 || {
        fail "Failed to create .venv. Check Python 3.11+ is available."
        exit 1
    }
    uv pip install "git+${REPO}" --quiet 2>&1 || {
        fail "Failed to install packages. Check network and try again."
        exit 1
    }
fi
ok "torch, numpy, matplotlib, seaborn, transformers, etc."

# 3. Add and update marketplaces
echo "[2/5] Marketplaces..."
for repo in stamate/ai-scientist-skills stamate/codex-plugin-cc K-Dense-AI/claude-scientific-skills; do
    claude plugin marketplace add "$repo" 2>/dev/null || true
done
for mkt in stm-ai-sci stm-codex claude-scientific-skills claude-plugins-official astral-sh claude-hud; do
    claude plugin marketplace update "$mkt" 2>/dev/null || true
done
ok "Marketplaces added and updated"

# 4. Install plugins at project scope
echo "[3/5] Plugins..."
core_plugins=(
    "ai-scientist@stm-ai-sci"
    "codex@stm-codex"
    "scientific-skills@claude-scientific-skills"
)
extra_plugins=(
    "superpowers@claude-plugins-official"
    "context7@claude-plugins-official"
    "code-review@claude-plugins-official"
    "astral@astral-sh"
    "claude-hud@claude-hud"
)

core_ok=0
for plugin in "${core_plugins[@]}"; do
    if claude plugin install "$plugin" --scope project 2>/dev/null; then
        ok "$plugin"
        ((core_ok++))
    else
        fail "$plugin"
    fi
done

for plugin in "${extra_plugins[@]}"; do
    if claude plugin install "$plugin" --scope project 2>/dev/null; then
        ok "$plugin"
    else
        warn "$plugin (optional, skipped)"
    fi
done

if [ $core_ok -lt 3 ]; then
    warn "Some core plugins failed. Install manually:"
    echo "    claude plugin install ai-scientist@stm-ai-sci --scope project"
    echo "    claude plugin install codex@stm-codex --scope project"
    echo "    claude plugin install scientific-skills@claude-scientific-skills --scope project"
fi

# 5. Verify installation
echo "[4/5] Verifying..."
if uv run ai-scientist-verify --quiet 2>/dev/null; then
    ok "Environment check passed"
else
    warn "Some checks failed — run 'uv run ai-scientist-verify' for details"
fi

# 6. Create/update CLAUDE.md
echo "[5/5] CLAUDE.md..."
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

## Skills

| Command | Description |
|---------|-------------|
| `/ai-scientist` | Full pipeline: ideation → experiment → plot → writeup → review |
| `/ai-scientist:ideation` | Generate research ideas with literature search |
| `/ai-scientist:experiment` | 4-stage BFTS experiment pipeline |
| `/ai-scientist:experiment-step` | Single BFTS iteration (internal) |
| `/ai-scientist:experiment-generate` | Code generation only (internal) |
| `/ai-scientist:experiment-execute` | Execution only (internal) |
| `/ai-scientist:plot` | Aggregate publication-quality figures |
| `/ai-scientist:writeup` | Generate LaTeX paper with citations |
| `/ai-scientist:review` | Structured peer review (single + panel + Codex) |
| `/ai-scientist:lit-search` | Standalone literature search |
| `/ai-scientist:workshop` | Interactive workshop description creator |
| `/ai-scientist:codex-review` | Codex panel paper review (optional) |

## Installed Plugins

### Core
- **ai-scientist** — Full research pipeline (ideation, experiment, writeup, review)
- **codex** — Codex delegation and code review (3 personas: Empiricist, Theorist, Practitioner)
- **scientific-skills** — 134 scientific skills (databases, tools, analysis)

### Enhancements
- **superpowers** — Planning before BFTS stages, brainstorming during ideation
- **context7** — Library docs lookup before experiment code generation
- **code-review** — Code quality review between BFTS stages (complements Codex ML review)
- **astral** — ruff lint + format on experiment code before execution
- **claude-hud** — Status line display

## Codex Integration (Optional)

When codex-plugin-cc is installed and `codex login` is authenticated:
- Stage-gate code review between BFTS stages
- Panel paper review (3 independent reviewer personas + Area Chair)
- Code-methods alignment (verifies paper claims match experiment code)
- Rescue delegation for stuck experiments

Control via config:
```yaml
codex:
  enabled: auto           # auto | true | false
  stage_gate_review: true
  panel_paper_review: true
  code_alignment: true
  rescue_on_stuck: true
  venue: auto             # auto | neurips | icml | iclr | workshop
```

## Scientific Skills Integration (Optional)

When claude-scientific-skills is installed:
- Multi-database literature search during ideation
- Enhanced scientific writing during writeup
- Publication-quality figure formatting
- Evidence quality assessment during review (GRADE framework)

Control via config:
```yaml
scientific_skills:
  enabled: auto               # auto | true | false
  enhanced_literature: true
  enhanced_writing: true
  enhanced_figures: true
  enhanced_review: true
```

## Review Pipeline

The paper review has 3 independent layers:
1. **Claude single reviewer** — NeurIPS-style review (always runs)
2. **Claude panel** — 3 personas (Empiricist, Theorist, Practitioner) + synthesis
3. **Codex panel** — 3 personas + Area Chair + code-methods alignment (optional)

Plus cross-review comparison that flags divergences >2 points.

## Install / Update

```bash
curl -fsSL https://raw.githubusercontent.com/stamate/ai-scientist-skills/main/scripts/install.sh | bash
```

## Run

```bash
claude '/ai-scientist --workshop examples/ideas/i_cant_believe_its_not_better.md'
claude '/ai-scientist'  # interactive — guides you through topic creation
```
CLAUDEMD
ok "CLAUDE.md created (always regenerated to stay current)"

echo ""
echo "=== Done ==="
echo ""
echo "  Verify: uv run ai-scientist-verify"
echo "  Run:    claude '/ai-scientist'"
