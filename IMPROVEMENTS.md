# Improvements

Suggested improvements for the ai-scientist-skills pipeline and its companion plugin integrations (claude-scientific-skills, codex-plugin-cc).

---

## 1. Plugin Detection: Replace Heuristic with Explicit Discovery

**Problem**: The orchestrator detects claude-scientific-skills by searching for a `*research-lookup*` SKILL.md path in plugin directories. If that skill is renamed, moved, or the plugin restructures, detection breaks silently.

**Fix**: Check for the plugin's `plugin.json` or `marketplace.json` identity instead of proxying through a specific skill name:

```bash
# Current (fragile)
find "$HOME/.claude/plugins" -name "SKILL.md" -path "*research-lookup*"

# Proposed (stable)
find "$HOME/.claude/plugins" ".claude/plugins" -maxdepth 5 \
  -name "marketplace.json" -exec grep -l '"claude-scientific-skills"' {} \;
```

Similarly for codex-plugin-cc, check for `"codex-plugin-cc"` in plugin.json rather than scanning for `*stamate-codex*` or `*codex-plugin-cc*` directory names.

**Files**: `skills/ai-scientist/SKILL.md`, `skills/ideation/SKILL.md`, `skills/writeup/SKILL.md`, `skills/review/SKILL.md`, `skills/experiment/SKILL.md`, `skills/codex-review/SKILL.md`

---

## 2. Define a Plugin Interface Contract

**Problem**: ai-scientist-skills hardcodes knowledge of codex-plugin-cc's command syntax (e.g., `/codex:paper-review --panel --venue <venue> --code <dir> --wait`) and claude-scientific-skills' skill names (e.g., `/research-lookup`, `/scientific-critical-thinking`). If either companion changes its interface, the orchestrator breaks with no clear error.

**Fix**: Add a `compatibility.json` to each companion plugin that declares the interface ai-scientist-skills depends on:

```json
{
  "plugin": "codex-plugin-cc",
  "ai_scientist_interface": {
    "version": "1.0",
    "commands": {
      "paper-review": {
        "flags": ["--panel", "--venue", "--code", "--wait"],
        "venues": ["neurips", "icml", "iclr", "acl", "nature", "workshop"]
      },
      "rescue": {
        "flags": ["--fresh", "--wait"]
      }
    }
  }
}
```

The orchestrator reads this at Phase 0 and validates before using any companion features. If the contract is missing or outdated, it degrades gracefully with a specific warning.

**Files**: New `compatibility.json` in each companion plugin; validation logic in `skills/ai-scientist/SKILL.md` Phase 0

---

## 3. Split experiment-step into Generate and Execute

**Problem**: The experiment-step skill generates code, executes it (up to 60 minutes), parses metrics, analyzes plots, and saves state -- all in a single agent invocation. A failure at minute 55 of execution wastes the entire turn's context window.

**Fix**: Split into two skills:

- `/ai-scientist:experiment-generate` -- Produces the Python code, validates it syntactically, saves to workspace
- `/ai-scientist:experiment-execute` -- Runs the code, parses metrics, analyzes plots, records the node

This way, if execution fails or times out, the generated code is already saved and can be retried or debugged without regenerating it. It also makes the execute step easily parallelizable across multiple experiment nodes.

**Files**: New `skills/experiment-generate/SKILL.md`, new `skills/experiment-execute/SKILL.md`, updates to `skills/experiment/SKILL.md` and `skills/experiment-step/SKILL.md`

---

## 4. Add Token/Cost Budget Estimation

**Problem**: Running the full pipeline with all 3 plugins -- ideation with 5 reflection rounds, 4 BFTS stages with parallel agents, Codex stage-gate reviews, panel review -- can consume an enormous number of tokens across both Claude and OpenAI APIs. There's no visibility into expected cost before or during a run.

**Fix**: Add a `tools/budget_estimator.py` that estimates token usage before execution:

```bash
python3 tools/budget_estimator.py --config templates/bfts_config.yaml --idea idea.json
```

Output:
```
Estimated token usage:
  Ideation (3 ideas, 5 reflections):   ~50K tokens
  Experiments (4 stages, 62 max iters): ~800K tokens
  Writeup (5 cite rounds, 3 reflections): ~120K tokens
  Review (Claude + Codex panel):         ~80K tokens
  ─────────────────────────────────────
  Total Claude:  ~1.05M tokens
  Total Codex:   ~150K tokens (if enabled)

  Estimated cost: $X.XX (Claude) + $Y.YY (Codex)
```

Also add a `--budget` flag to the orchestrator that stops execution if estimated remaining cost exceeds the budget.

**Files**: New `tools/budget_estimator.py`, updates to `skills/ai-scientist/SKILL.md`

---

## 5. Make Multi-Seed Validation More Robust

**Problem**: The current multi-seed validation uses `sed` to swap `torch.manual_seed(42)` with other seeds. This is fragile -- the generated code might use `random.seed()`, `np.random.seed()`, different variable names, or set seeds in multiple places.

**Fix**: Use the device preamble's existing seed-setting block (from `device_utils.py`) and make it accept a `SEED` environment variable:

```python
# In device_utils.py get_device_preamble():
SEED = int(os.environ.get("SEED", "42"))
torch.manual_seed(SEED)
if torch.cuda.is_available():
    torch.cuda.manual_seed_all(SEED)
np.random.seed(SEED)
random.seed(SEED)
```

Then multi-seed validation becomes:
```bash
SEED=42 python3 runfile.py
SEED=123 python3 runfile.py
SEED=456 python3 runfile.py
```

No sed, no fragile text replacement. The experiment-step skill already uses `get_device_preamble()` to generate the seed block -- just make it read from the environment.

**Files**: `tools/device_utils.py`, `skills/experiment/SKILL.md` (step 5c), `skills/experiment-step/SKILL.md`

---

## 6. Add a Venue/Template Extension System

**Problem**: Only ICML and ICBINB templates are supported. Adding a new venue (e.g., NeurIPS, ICLR, ACL) requires editing template files, the config system, the writeup skill, and the venue calibration in codex-plugin-cc. There's no clear extension path.

**Fix**: Make templates self-describing with a `venue.json` manifest:

```
templates/latex/neurips/
  venue.json          # {"name": "neurips", "pages": 8, "style": "neurips2025.sty", ...}
  template.tex
  neurips2025.sty
  neurips2025.bst
```

The writeup skill discovers available venues by scanning `templates/latex/*/venue.json` instead of hardcoding `icbinb|icml`. The `--type` argument becomes `--venue` and accepts any discovered venue name.

```bash
python3 tools/latex_compiler.py list-venues   # Shows all available templates
python3 tools/latex_compiler.py setup <dir> --venue neurips
```

**Files**: New `venue.json` per template, updates to `tools/latex_compiler.py`, `tools/config.py`, `skills/writeup/SKILL.md`, `skills/ai-scientist/SKILL.md`

---

## 7. Add Experiment Checkpointing Within Stages

**Problem**: The pipeline supports resuming at the stage level (via `state_manager.py status`), but if a stage crashes mid-iteration (e.g., after 15 of 20 Stage 1 iterations), all progress within that stage's iterations is preserved in the journal -- but the orchestrator doesn't know which iteration to resume from. It re-reads journal-summary and continues, which works, but there's no explicit iteration checkpoint.

**Fix**: Add an `iteration_count` field to the stage state in `experiment_state.json`:

```json
{
  "current_stage": "stage1_initial",
  "stages": {
    "stage1_initial": {
      "status": "in_progress",
      "iteration": 15,
      "max_iterations": 20
    }
  }
}
```

Update `state_manager.py add-node` to increment this counter. The experiment skill reads it on resume and skips directly to the correct iteration.

**Files**: `tools/state_manager.py`, `skills/experiment/SKILL.md`

---

## 8. Add a Dry-Run Mode

**Problem**: There's no way to validate the pipeline configuration and environment without actually running experiments. Users discover issues (missing LaTeX, wrong Python version, missing API keys) only after the pipeline has already started.

**Fix**: Add `--dry-run` to the orchestrator that validates everything without executing:

```bash
/ai-scientist --workshop topic.md --dry-run
```

This would:
1. Run `verify_setup.py` (already exists)
2. Validate the workshop file format
3. Load and validate the config
4. Check LaTeX compilation with a dummy document
5. Test S2 API connectivity
6. Verify Codex auth (if enabled)
7. Check scientific-skills availability
8. Estimate token budget
9. Report: "Pipeline ready. Estimated duration: X hours. All checks passed."

**Files**: Updates to `skills/ai-scientist/SKILL.md`, minor additions to `tools/verify_setup.py`

---

## 9. Parallel Literature Search in Ideation

**Problem**: During ideation, the enhanced literature search runs sequentially: S2 first, then `/research-lookup`, then `/paper-lookup`, then `/database-lookup`. Each round waits for the previous one to complete. For 3 ideas with 5 reflection rounds each, this adds significant latency.

**Fix**: Run the search backends in parallel using Agent subagents:

```
Agent 1: python3 tools/search.py "<query>"        # S2
Agent 2: /research-lookup "<query>"                # Perplexity
Agent 3: /paper-lookup "<query>"                   # 10 databases
```

Merge results after all complete. The ideation skill already uses the Agent tool for experiment-step parallelism -- apply the same pattern to literature search.

**Files**: `skills/ideation/SKILL.md` (step 2b + Enhanced Literature Search section)

---

## 10. Add Review Calibration Feedback Loop

**Problem**: The review phase generates scores but doesn't feed them back into the pipeline. If the paper scores poorly (e.g., Overall < 5), the user has to manually decide whether to revise and resubmit. The pipeline just stops.

**Fix**: Add an optional `--revise` mode to the orchestrator that, when the review score is below a configurable threshold, automatically:

1. Extracts actionable weaknesses from the review
2. Maps each weakness to a pipeline phase (e.g., "missing baselines" -> experiment, "unclear writing" -> writeup)
3. Re-runs the relevant phases with the review feedback injected into the task description
4. Re-reviews the revised paper

This creates a closed loop: write -> review -> revise -> re-review. Cap at 2 revision cycles to prevent infinite loops.

```yaml
revision:
  enabled: false              # opt-in
  score_threshold: 5          # re-run if Overall < this
  max_cycles: 2
```

**Files**: New section in `skills/ai-scientist/SKILL.md`, updates to `templates/bfts_config.yaml`
