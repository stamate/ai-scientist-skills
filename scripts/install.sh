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
#
# Under `curl | bash` the shell is non-interactive and does NOT source
# ~/.bashrc / ~/.zshrc, so tools installed via nvm/npm/uv often aren't
# on PATH. Common on WSL. Probe likely install locations, source nvm if
# present, and only then run `command -v`.

# Add common binary dirs to PATH if they exist and aren't already there.
# $HOME/.claude/local is where Claude Code's native installer puts the binary.
for p in \
    "$HOME/.claude/local" \
    "$HOME/.local/bin" \
    "$HOME/.npm-global/bin" \
    "$HOME/.cargo/bin" \
    "$HOME/.volta/bin" \
    "/usr/local/bin" \
    "/opt/homebrew/bin"
do
    case ":$PATH:" in
        *":$p:"*) ;;
        *) [ -d "$p" ] && PATH="$p:$PATH" ;;
    esac
done

# nvm doesn't put its node bin on PATH until sourced.
if [ -s "$HOME/.nvm/nvm.sh" ]; then
    export NVM_DIR="$HOME/.nvm"
    # shellcheck source=/dev/null
    . "$HOME/.nvm/nvm.sh" >/dev/null 2>&1 || true
fi

export PATH

for cmd in uv claude; do
    if ! command -v "$cmd" &>/dev/null; then
        fail "$cmd not found on PATH."
        echo ""
        echo "    Non-interactive shells (like 'curl | bash') don't source your"
        echo "    shell rc files, so tools installed via nvm/npm/uv may be missing"
        echo "    from PATH even if 'which $cmd' works in your normal terminal."
        echo ""
        echo "    Find where $cmd lives, then retry with PATH prepended:"
        echo "      which $cmd        # in a normal terminal"
        echo "      PATH=\"<that-dir>:\$PATH\" bash <(curl -fsSL <this-script-url>)"
        echo ""
        echo "    Or download and run the script directly:"
        echo "      curl -fsSL <this-script-url> -o install.sh && bash install.sh"
        exit 1
    fi
done

# 2. Create .venv and install Python tools
echo "[1/7] Python tools..."
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
echo "[2/7] Marketplaces..."
for repo in stamate/ai-scientist-skills stamate/codex-plugin-cc; do
    claude plugin marketplace add "$repo" 2>/dev/null || true
done
for mkt in stm-ai-sci stm-codex; do
    claude plugin marketplace update "$mkt" 2>/dev/null || true
done
ok "Marketplaces added and updated"

# 4. Install plugins at local scope
echo "[3/7] Plugins..."
core_plugins=(
    "ai-scientist@stm-ai-sci"
    "codex@stm-codex"
)

core_ok=0
for plugin in "${core_plugins[@]}"; do
    # Force reinstall to ensure latest version from marketplace
    claude plugin uninstall "$plugin" --scope local 2>/dev/null || true
    if claude plugin install "$plugin" --scope local 2>/dev/null; then
        ok "$plugin"
        ((core_ok++))
    else
        fail "$plugin"
    fi
done

if [ $core_ok -lt 2 ]; then
    warn "Some core plugins failed. Install manually:"
    echo "    claude plugin install ai-scientist@stm-ai-sci --scope local"
    echo "    claude plugin install codex@stm-codex --scope local"
fi

# 4b. Scientific skills — symlinked subset (only the 7 skills the pipeline actually uses).
# Avoids plugin-level bloat (134 skills from scientific-skills, 19 from scientific-writer)
# by shallow-cloning both upstreams into .aisci-cache/ and symlinking only what's used.
echo "[4/7] Scientific skills (symlinked subset)..."

WRITER_CACHE=".aisci-cache/scientific-writer"
LOOKUP_CACHE=".aisci-cache/scientific-skills"
WRITER_SKILLS=(research-lookup scientific-writing citation-management scientific-critical-thinking)
LOOKUP_SKILLS=(paper-lookup database-lookup scientific-visualization)

clone_or_pull() {
    local cache="$1" repo="$2"
    if [ ! -d "$cache/.git" ]; then
        mkdir -p "$(dirname "$cache")"
        git clone --depth=1 "$repo" "$cache" --quiet 2>&1 \
            || { warn "Failed to clone $repo"; return 1; }
    else
        (cd "$cache" && git pull --quiet --ff-only 2>&1) \
            || warn "Cache update failed for $cache — using existing copy"
    fi
    return 0
}

symlink_skills() {
    local src_base="$1"; shift
    mkdir -p .claude/skills
    for s in "$@"; do
        local src="$src_base/$s"
        if [ -d "$src" ]; then
            ln -sfn "$src" ".claude/skills/$s"
            ok "$s"
        else
            warn "$s not found in $src_base"
        fi
    done
}

if clone_or_pull "$WRITER_CACHE" "https://github.com/K-Dense-AI/claude-scientific-writer.git"; then
    symlink_skills "$(cd "$WRITER_CACHE" && pwd)/skills" "${WRITER_SKILLS[@]}"
fi

if clone_or_pull "$LOOKUP_CACHE" "https://github.com/K-Dense-AI/claude-scientific-skills.git"; then
    symlink_skills "$(cd "$LOOKUP_CACHE" && pwd)/scientific-skills" "${LOOKUP_SKILLS[@]}"
fi

# 5. Choose compute backend
echo "[5/7] Compute backend..."
# Copy default config to project if not present
if [ ! -f config.yaml ]; then
    uv run ai-scientist-config --config templates/bfts_config.yaml > config.yaml 2>/dev/null
fi
current_backend=$(grep "backend:" config.yaml | head -1 | awk '{print $2}' | tr -d "'" | tr -d '"')

if [ -z "$current_backend" ] || [ "$current_backend" = "''" ] || [ "$current_backend" = '""' ]; then
    echo ""
    echo "  Where would you like to run experiments?"
    echo "    1) Local — use this machine"
    echo "    2) Modal.com — cloud GPUs (A100, H100, T4, etc.)"
    echo ""
    printf "  Choose [1/2] (default: 1): "
    choice=""
    read -r choice < /dev/tty 2>/dev/null || choice="1"
    case "$choice" in
        2|modal|Modal)
            # Install modal if not present
            if ! uv run modal --version &>/dev/null; then
                echo "  Installing modal..."
                uv pip install modal --quiet 2>&1 || {
                    fail "Failed to install modal package"
                    warn "Defaulting to local"
                    uv run ai-scientist-config --config config.yaml --set compute.backend=local --save >/dev/null 2>&1
                    ok "Local (modal install failed)"
                    choice="done"
                }
            fi

            if [ "$choice" != "done" ]; then
                # Authenticate
                if ! uv run modal profile current &>/dev/null; then
                    echo ""
                    echo "  Modal authentication required."
                    echo "  Get your token command at: https://modal.com/settings/tokens"
                    echo ""
                    echo "    1) Paste your 'modal token set' command"
                    echo "    2) Open browser (modal setup)"
                    echo "    3) Skip — I'll set it up later"
                    echo ""
                    printf "  Choose [1-3]: "
                    auth_choice=""
                    read -r auth_choice < /dev/tty 2>/dev/null || auth_choice="3"
                    case "$auth_choice" in
                        1)
                            echo ""
                            echo "  Paste the command from Modal (e.g., modal token set --token-id ak-xxx --token-secret as-xxx):"
                            printf "  > "
                            token_cmd=""
                            read -r token_cmd < /dev/tty 2>/dev/null || token_cmd=""
                            # Run the command directly
                            eval "uv run $token_cmd" 2>&1 || true
                            if uv run modal profile current &>/dev/null; then
                                ok "Modal authenticated"
                            else
                                warn "Auth may have failed — verify with: uv run modal profile current"
                            fi
                            ;;
                        2)
                            echo "  Running modal setup (opens browser)..."
                            uv run modal setup < /dev/tty || warn "modal setup failed"
                            ;;
                        *)
                            warn "Skipped auth — run 'uv run modal setup' before using Modal"
                            ;;
                    esac
                else
                    ok "Modal already authenticated"
                fi

                # Choose GPU
                echo ""
                echo "  Which GPU?"
                echo "    1) A100 (default)  2) H100  3) T4  4) L4"
                printf "  Choose [1-4] (default: 1): "
                gpu_choice=""
                read -r gpu_choice < /dev/tty 2>/dev/null || gpu_choice="1"
                case "$gpu_choice" in
                    2) gpu="H100" ;;
                    3) gpu="T4" ;;
                    4) gpu="L4" ;;
                    *) gpu="A100" ;;
                esac
                uv run ai-scientist-config --config config.yaml --set compute.backend=modal compute.modal.gpu="$gpu" --save >/dev/null 2>&1
                ok "Modal.com with $gpu GPU"
            fi
            ;;
        *)
            uv run ai-scientist-config --config config.yaml --set compute.backend=local --save >/dev/null 2>&1
            ok "Local"
            ;;
    esac
else
    ok "Already set: $current_backend"
fi

# 6. Verify installation
echo "[6/7] Verifying..."
if uv run ai-scientist-verify --quiet 2>/dev/null; then
    ok "Environment check passed"
else
    warn "Some checks failed — run 'uv run ai-scientist-verify' for details"
fi

# 7. Create/update CLAUDE.md
echo "[7/7] CLAUDE.md..."
cat > CLAUDE.md << 'CLAUDEMD'
# AI Scientist Skills

## Environment

This project uses `uv` with a `.venv` directory.

**CRITICAL RULES:**
1. **ALWAYS** prefix `ai-scientist-*` commands with `uv run`
2. **ALWAYS** use `--config config.yaml` (NOT `templates/bfts_config.yaml`) — the project config has the user's compute backend and settings
3. **Never** `cd` into the plugin cache directory

CLI commands:

```bash
uv run ai-scientist-verify
uv run ai-scientist-device --info
uv run ai-scientist-config --config config.yaml
uv run ai-scientist-state status <exp_dir>
uv run ai-scientist-search "query" --limit 10
uv run ai-scientist-metrics <file>
uv run ai-scientist-latex compile <dir>
uv run ai-scientist-pdf <file>
uv run ai-scientist-budget --config config.yaml
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

### Core plugins
- **ai-scientist** — Full research pipeline (ideation, experiment, writeup, review)
- **codex** — Codex delegation and code review (3 personas: Empiricist, Theorist, Practitioner)

### Symlinked scientific skills (in `.claude/skills/`)

Only the 7 skills the pipeline actually references — shallow-cloned from the upstream repos into `.aisci-cache/` and symlinked in. No scientific-writer or scientific-skills plugin is installed (avoids 153 unused skills and the mistrigger risk that comes with them).

From **claude-scientific-writer**:
- **research-lookup** — Parallel API / Perplexity academic search
- **scientific-writing** — IMRAD prose, two-stage outline → paragraphs
- **citation-management** — BibTeX, DOI verification via CrossRef
- **scientific-critical-thinking** — GRADE framework, bias detection

From **claude-scientific-skills**:
- **paper-lookup** — 10 academic paper databases (PubMed, PMC, bioRxiv, arXiv, OpenAlex, Crossref, S2, CORE, Unpaywall, medRxiv)
- **database-lookup** — 78 scientific databases (PubChem, ChEMBL, UniProt, Ensembl, PDB, AlphaFold, ClinicalTrials, FDA, …)
- **scientific-visualization** — publication-ready multi-panel figures (Nature/Science/Cell styling)

Any global plugins you already have (superpowers, context7, code-review, astral, claude-hud, …) continue to work on top — they're installed separately at user scope, not re-installed here.

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

## Scientific skills — where they slot in

The 7 symlinked skills map directly to pipeline phases:

- **Ideation** (lit search): `research-lookup`, `paper-lookup`, `database-lookup`
- **Writeup**: `scientific-writing`, `citation-management`
- **Plot**: `scientific-visualization`
- **Review**: `scientific-critical-thinking`

Skills live in `.claude/skills/*` as symlinks into `.aisci-cache/` (two shallow clones: `scientific-writer/` and `scientific-skills/`). To refresh, rerun the installer — it `git pull`s both caches.

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
