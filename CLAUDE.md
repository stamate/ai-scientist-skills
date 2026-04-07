# AI Scientist Skills for Claude Code

This project provides a complete AI research automation pipeline as Claude Code skills. It reimplements the [AI-Scientist-v2](https://github.com/SakanaAI/AI-Scientist) workflow using Claude Code as the central agent.

## Skills

| Command | Description |
|---------|-------------|
| `/ai-scientist` | Full pipeline: ideation → experiment → plot → writeup → review |
| `/ai-scientist:ideation` | Generate research ideas with literature search |
| `/ai-scientist:experiment` | 4-stage BFTS experiment pipeline |
| `/ai-scientist:experiment-step` | Single BFTS iteration (internal) |
| `/ai-scientist:plot` | Aggregate publication-quality figures |
| `/ai-scientist:writeup` | Generate LaTeX paper with citations |
| `/ai-scientist:review` | Structured peer review (NeurIPS format) |
| `/ai-scientist:lit-search` | Standalone literature search |
| `/ai-scientist:workshop` | Interactive workshop description creator |
| `/ai-scientist:codex-review` | Codex panel paper review with code-methods alignment (optional) |

## Project Layout

- `skills/` — Skill directories, each containing a `SKILL.md` (Agent Skills standard)
- `tools/` — Python utilities (search, state management, device detection, metrics, LaTeX, PDF)
- `templates/` — LaTeX templates (ICML, ICBINB), config, schema, review examples
- `examples/` — Example workshop descriptions and research ideas
- `experiments/` — Generated experiment outputs (gitignored)

## Tool Usage

When running from a cloned repo, tools are invoked via `uv run python3 tools/<module>.py`. When installed as a plugin, skills discover the plugin root first and use absolute paths (`"$AISCIENTIST_ROOT/tools/<module>.py"`). See any skill's "Locate Plugin Root" step for the discovery pattern.

Tool reference (from project root):

```bash
uv run python3 tools/verify_setup.py              # Verify all prerequisites
uv run python3 tools/device_utils.py              # Detect CUDA/MPS/CPU
uv run python3 tools/search.py "query"            # Search papers (S2 API)
uv run python3 tools/state_manager.py init --idea FILE --config FILE  # Init experiment
uv run python3 tools/state_manager.py status DIR            # Check experiment state
uv run python3 tools/state_manager.py select-nodes DIR STAGE # Pick nodes to expand
uv run python3 tools/state_manager.py add-node DIR STAGE ... # Record experiment result
uv run python3 tools/state_manager.py best-node DIR STAGE   # Get best node
uv run python3 tools/state_manager.py save-best DIR STAGE   # Save best node code to file
uv run python3 tools/state_manager.py transition DIR S1 S2  # Move to next stage
uv run python3 tools/state_manager.py stage-briefing DIR STAGE  # Stage handoff summary
uv run python3 tools/state_manager.py journal-summary DIR STAGE # Stage progress counts
uv run python3 tools/state_manager.py node-info DIR STAGE ID    # Node details
uv run python3 tools/state_manager.py update-state DIR ...      # Update experiment state
uv run python3 tools/metric_parser.py FILE        # Parse metrics from output
uv run python3 tools/latex_compiler.py compile DIR # Compile LaTeX to PDF
uv run python3 tools/pdf_reader.py FILE           # Extract PDF text
uv run python3 tools/config.py --config FILE      # Load/display config
uv run python3 tools/config.py --set KEY=VAL ...  # Override config values (e.g. codex.enabled=false)
uv run python3 tools/budget_estimator.py --config FILE  # Estimate token usage and cost
```

## Environment

- **Python**: 3.11+
- **PyTorch**: 2.0+ (CUDA, MPS, or CPU)
- **LaTeX**: pdflatex + bibtex (BasicTeX on macOS, texlive on Linux)
- **Optional**: `S2_API_KEY` env var for Semantic Scholar API (higher rate limits)

## Experiment Code Conventions

All generated experiment code must:
1. Auto-detect device (CUDA/MPS/CPU) — never hardcode `cuda`
2. Print metrics as `metric_name: value` for parsing
3. Save plots to `figures/` directory
4. Set random seeds for reproducibility
5. Keep execution under 60 minutes

## Scientific Skills Integration (Optional)

When the **claude-scientific-skills** plugin is installed alongside ai-scientist-skills, the pipeline gains:

- **Multi-Database Literature**: `/research-lookup` (Perplexity-powered), `/paper-lookup` (10 databases), `/database-lookup` (78+ databases) during ideation
- **Enhanced Writing**: `/scientific-writing` (IMRAD prose, two-stage process) + `/citation-management` (DOI verification via CrossRef) during writeup
- **Publication Figures**: `/scientific-visualization` (journal-specific formatting, colorblind-safe palettes, significance markers) during plot generation
- **Evidence Assessment**: `/scientific-critical-thinking` (GRADE framework, bias detection, logical fallacy identification) during review

All features are **optional**. Control via config:

```yaml
scientific_skills:
  enabled: auto               # auto | true | false
  enhanced_literature: true
  enhanced_writing: true
  enhanced_figures: true
  enhanced_review: true
```

## Codex Integration (Optional)

When the **codex-plugin-cc** plugin is installed alongside ai-scientist-skills, the pipeline gains:

- **Panel Paper Review**: 3 independent reviewer personas (Empiricist, Theorist, Practitioner) + Area Chair synthesis via `/codex:paper-review --panel`
- **Venue Calibration**: Reviews calibrated to conference standards (NeurIPS ~25%, ICML ~25%, workshop ~50-70%)
- **Code-Methods Alignment**: Verifies paper claims match experiment code (catches hyperparameter mismatches, data leakage, undocumented steps)
- **Stage-Gate Code Review**: Adversarial code review of best experiment code between BFTS stages
- **Rescue Delegation**: Codex diagnoses stuck experiments (Stage 1 failing after 80%+ iterations)

All Codex features are **optional** — the pipeline works identically without it. Control via config:

```yaml
codex:
  enabled: auto           # auto | true | false
  stage_gate_review: true
  panel_paper_review: true
  code_alignment: true
  rescue_on_stuck: true
  venue: auto             # auto | neurips | icml | iclr | workshop
```

```yaml
revision:
  enabled: false
  score_threshold: 5
  max_passes: 2
  prompt_before_revision: true
```

## Pre-commit Validation

Run before committing to catch common issues:
```bash
uv run scripts/pre-commit-check.py
```
Checks: SKILL.md frontmatter validity, settings.json path consistency, YAML config parsing, step numbering gaps, marketplace.json completeness.
