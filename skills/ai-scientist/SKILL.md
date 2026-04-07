---
name: ai-scientist
description: Run the complete AI Scientist pipeline — from research ideation through experiment execution, paper writing, and peer review. Orchestrates all sub-skills.
---


# AI Scientist — Full Research Pipeline

You are the AI Scientist, an autonomous research agent that generates novel research ideas, conducts experiments, writes papers, and performs peer review. This orchestrates the complete pipeline by invoking sub-skills.

## Arguments

- `--workshop <path>`: Path to workshop/topic description (.md file)
- `--idea <path>`: Path to pre-generated idea JSON (skip ideation if provided)
- `--idea-idx <N>`: Index of the idea to use from the JSON (default: 0)
- `--config <path>`: Path to config YAML (default: `templates/bfts_config.yaml`)
- `--exp-dir <path>`: Resume from existing experiment directory
- `--type <icbinb|icml>`: Paper template type (default: icbinb)
- `--skip-writeup`: Skip the paper writing phase
- `--skip-review`: Skip the review phase
- `--seed-code <path>`: Path to optional seed code file
- `--use-codex`: Force enable Codex integration (even if auto-detection fails)
- `--no-codex`: Force disable Codex integration (even if Codex is installed)
- `--no-scientific-skills`: Disable claude-scientific-skills integration (even if installed)

Parse from the user's message. If none of `--workshop`, `--idea`, or `--exp-dir` is provided, start with Phase 0.5 (Workshop Creator) to interactively guide the user.

## Pipeline Overview

```
0.5. Workshop    → topic.md          (interactive topic creation, if needed)
1.   Ideation    → ideas.json        (generate research proposals)
2.   Experiment  → experiment results (4-stage BFTS tree search)
3.   Plot        → figures/           (publication-quality figures)
4.   Writeup     → paper.pdf          (LaTeX paper generation)
5.   Review      → review.json        (structured peer review)
```

## Procedure

### Phase 0: Setup

1. **Verify environment**:
   ```bash
   python3 tools/verify_setup.py
   ```
   If this fails (missing dependencies, wrong Python version, etc.), **stop and guide the user** through fixing the issues instead of continuing. Common problems:
   - `python: command not found` → tell the user to use `python3` or activate a virtualenv
   - `TypeError: unsupported operand type(s) for |` → Python version is below 3.10, tell user to install Python 3.11+
   - Missing packages → tell user to run `pip install -r requirements.txt`

2. **Detect device**:
   ```bash
   python3 tools/device_utils.py --info
   ```

3. **Load configuration**:
   ```bash
   python3 tools/config.py --config <config_path>
   ```

4. **Check LaTeX** (optional, only needed for writeup):
   ```bash
   python3 tools/latex_compiler.py check
   ```
   Warn if pdflatex or bibtex is missing — the experiment can still run, paper generation will be skipped.

5. **Detect Codex** (optional enhancement):

   Check four conditions — CLI binary, Claude Code plugin, authentication, and config toggle:
   ```bash
   which codex 2>/dev/null && echo "CLI_OK" || echo "CLI_MISSING"
   test -d "$HOME/.claude/plugins/marketplaces/stamate-codex" -o -d "$HOME/.claude/plugins/marketplaces/codex-plugin-cc" && echo "PLUGIN_OK" || echo "PLUGIN_MISSING"
   codex login status 2>/dev/null && echo "AUTH_OK" || echo "AUTH_MISSING"
   ```
   Also read the `codex.enabled` value from the loaded config (step 3 above).

   Determine `CODEX_ENABLED`:
   - If `--no-codex` is set: `CODEX_ENABLED=false` regardless of anything else
   - If `codex.enabled` is `"false"` in config: `CODEX_ENABLED=false`
   - If `--use-codex` is set: `CODEX_ENABLED=true` (warn if CLI/plugin missing)
   - If `codex.enabled` is `"auto"`: `CODEX_ENABLED=true` only if ALL of: CLI found, plugin directory exists, auth OK
   - If `codex.enabled` is `"true"`: `CODEX_ENABLED=true` (warn if CLI/plugin missing)

   Print result:
   - If `CODEX_ENABLED=true`: "Codex detected — enhanced reviews enabled"
   - If CLI missing: "Codex CLI not found — install with: npm install -g @openai/codex"
   - If CLI found but plugin missing: "Codex CLI found but codex-plugin-cc not installed — install with: claude install gh:stamate/codex-plugin-cc"
   - If CLI + plugin found but auth failed: "Codex installed but not authenticated — run: codex login"
   - If `CODEX_ENABLED=false`: "Codex not enabled — using standard pipeline"

6. **Detect claude-scientific-skills** (optional enhancement):

   Check if the claude-scientific-skills plugin is installed:
   ```bash
   # Check common marketplace and cache directories
   find "$HOME/.claude/plugins" -maxdepth 4 -name "SKILL.md" -path "*scientific*" 2>/dev/null | head -1 | grep -q . && echo "SCIENTIFIC_SKILLS_OK" || echo "SCIENTIFIC_SKILLS_MISSING"
   ```
   Also read the `scientific_skills.enabled` value from the loaded config (step 3).

   Determine `SCIENTIFIC_SKILLS_ENABLED`:
   - If `--no-scientific-skills` is set: `SCIENTIFIC_SKILLS_ENABLED=false`
   - If `scientific_skills.enabled` is `"false"` in config: `SCIENTIFIC_SKILLS_ENABLED=false`
   - If `scientific_skills.enabled` is `"auto"`: `SCIENTIFIC_SKILLS_ENABLED=true` only if plugin found
   - If `scientific_skills.enabled` is `"true"`: `SCIENTIFIC_SKILLS_ENABLED=true` (warn if missing)

   Print result:
   - If `SCIENTIFIC_SKILLS_ENABLED=true`: "Scientific skills detected — enhanced literature, writing, and review enabled"
   - If not found: "claude-scientific-skills not found — using standard pipeline (install for 78+ database access, DOI verification, and IMRAD writing)"

### Phase 0.5: Workshop Creator

**Skip if** `--workshop`, `--idea`, or `--exp-dir` is already provided.

If the user didn't specify a research topic, invoke the workshop skill to guide them interactively:
```
/ai-scientist:workshop
```

This will ask the user about their research interests and generate a workshop description `.md` file. Use the output path as `--workshop` for the next phase.

### Phase 1: Ideation

**Skip if** `--idea` is provided.

Invoke the ideation skill:
```
/ai-scientist:ideation --workshop <workshop_path> --num-ideas 3
```

This generates a JSON file with research ideas.

### Phase 2: Select Idea

If multiple ideas exist, select the one at `--idea-idx`:
```bash
python3 -c "
import json
ideas = json.load(open('<ideas_json_path>'))
idea = ideas[<idea_idx>]
print(f'Selected: {idea[\"Title\"]}')
json.dump(idea, open('<selected_idea_path>', 'w'), indent=2)
"
```

If `--seed-code` is provided, inject it into the idea:
```python
idea["Code"] = open(seed_code_path).read()
```

### Phase 3: Experiment

Invoke the experiment skill. If Codex is disabled, pass `--no-codex` so experiment-level Codex hooks are also skipped:

**If `CODEX_ENABLED`**:
```
/ai-scientist:experiment --idea <selected_idea_path> --config <config_path>
```

**If NOT `CODEX_ENABLED`**:
```
/ai-scientist:experiment --idea <selected_idea_path> --config <config_path> --no-codex
```

This runs the 4-stage BFTS pipeline and produces experiment results.

**Resume support**: If `--exp-dir` is provided, the experiment skill will detect the last completed stage and resume from there.

### Phase 4: Plot Aggregation

Invoke the plot skill:
```
/ai-scientist:plot --exp-dir <exp_dir>
```

This generates publication-quality figures from all experiment stages.

### Phase 5: Paper Writing

**Skip if** `--skip-writeup` is set.

Invoke the writeup skill:
```
/ai-scientist:writeup --exp-dir <exp_dir> --type <icbinb|icml>
```

This generates a complete LaTeX paper with citations and compiles to PDF.

### Phase 6: Paper Review

**Skip if** `--skip-review` is set, or if no PDF was generated.

Run the review skill. Forward `--no-codex` if Codex is disabled so the review skill skips Step 9:

**If `CODEX_ENABLED`**:
```
/ai-scientist:review --pdf <exp_dir>/paper.pdf --exp-dir <exp_dir>
```
The review skill's Step 9 automatically invokes `/codex:paper-review --panel --venue <venue>` with code-methods alignment.

**If NOT `CODEX_ENABLED`**:
```
/ai-scientist:review --pdf <exp_dir>/paper.pdf --exp-dir <exp_dir> --no-codex
```

Also forward `--no-scientific-skills` if `SCIENTIFIC_SKILLS_ENABLED` is false, to skip Step 9 (evidence assessment) in the review skill.

The `/ai-scientist:codex-review` skill exists for standalone use when the user wants Codex-only review without the Claude review.

### Phase 7: Summary Report

After all phases complete, provide a summary:

```
═══════════════════════════════════════════════════════
  AI Scientist Pipeline Complete
═══════════════════════════════════════════════════════

  Idea:        <idea title>
  Device:      <cuda|mps|cpu>
  Experiment:  <exp_dir>

  Stages Completed:
    Stage 1 (Initial):   ✓ (<N> nodes, best metric: <value>)
    Stage 2 (Baseline):  ✓ (<N> nodes, best metric: <value>)
    Stage 3 (Creative):  ✓ (<N> nodes, best metric: <value>)
    Stage 4 (Ablation):  ✓ (<N> nodes, best metric: <value>)

  Figures:     <N> figures in <exp_dir>/figures/
  Paper:       <exp_dir>/paper.pdf (<N> pages)
  Review:      <exp_dir>/review.json
    Overall Score: <score>/10
    Decision:      <Accept/Reject>
  Evidence:    <exp_dir>/evidence_assessment.md (if scientific-skills available)
    Quality:     <High/Moderate/Low> (GRADE framework)
  Codex Review: <exp_dir>/codex_review.md (if Codex available)
    Panel:       <recommendation> (Empiricist/Theorist/Practitioner consensus)
    Alignment:   <aligned/minor-discrepancies/major-discrepancies>

═══════════════════════════════════════════════════════
```

## Error Handling

- **Ideation fails**: Report and stop. Check workshop description format.
- **Stage 1 fails** (no working implementation after max iters): Report failure. The idea may be too complex.
- **LaTeX compilation fails**: Continue without PDF. Report the error.
- **Review fails**: Continue. The paper is still available.
- Always save partial results — the experiment can be resumed later.

## Resume Support

The pipeline supports resuming at any phase:
- Provide `--exp-dir` to skip ideation and experiment init
- Check `state/experiment_state.json` for current phase and stage
- Skip already-completed phases
- Resume the current phase from its last checkpoint

## Notes

- The full pipeline can take several hours depending on experiment complexity and device speed.
- Token usage scales with the number of BFTS iterations and parallel agents.
- For a quick test run, use `--config` with reduced iterations:
  ```bash
  # Create a test config with fewer iterations
  python3 tools/config.py --set agent.stages.stage1_max_iters=5 agent.stages.stage2_max_iters=3 agent.stages.stage3_max_iters=3 agent.stages.stage4_max_iters=3
  ```
