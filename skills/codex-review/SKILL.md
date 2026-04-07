---
name: codex-review
description: Enhanced paper review using Codex panel mode — three independent reviewer personas (Empiricist, Theorist, Practitioner) plus Area Chair synthesis, with venue calibration and code-methods alignment checking. Requires codex-plugin-cc to be installed.
---


# Codex-Enhanced Paper Review

You are a review coordinator that leverages the Codex plugin to produce a multi-perspective panel review of a research paper, optionally verifying that the paper's methods section accurately describes the experiment code.

## Prerequisites

This skill requires the **codex-plugin-cc** Claude Code plugin to be installed. If Codex is not available, inform the user and suggest using `/ai-scientist:review` instead.

## Arguments

- `--pdf <path>`: Path to the paper PDF (required)
- `--exp-dir <path>`: Experiment directory for code-methods alignment (optional)
- `--venue <neurips|icml|iclr|acl|nature|workshop>`: Venue calibration (default: workshop)
- `--no-panel`: Disable panel mode (single reviewer instead of 3+synthesis)
- `--no-alignment`: Skip code-methods alignment even if --exp-dir is provided
- `--output <path>`: Output directory (default: same as PDF directory)

Parse from the user's message.

## Venue Mapping

When called from the orchestrator, map `--type` to `--venue`:
- `icbinb` → `workshop`
- `icml` → `icml`

## Procedure

### 1. Check Codex Availability

Both the Codex CLI and the codex-plugin-cc Claude Code plugin must be installed:

```bash
which codex 2>/dev/null && echo "CLI_OK" || echo "CLI_MISSING"
```

Also verify the Claude Code plugin is registered (check common install paths):
```bash
test -d "$HOME/.claude/plugins/marketplaces/stamate-codex" -o -d "$HOME/.claude/plugins/marketplaces/codex-plugin-cc" && echo "PLUGIN_OK" || echo "PLUGIN_MISSING"
```

If CLI is missing:
- Print: "Codex CLI not found. Install with: npm install -g @openai/codex"
- **Stop here.**

If CLI found but plugin missing:
- Print: "Codex CLI found but codex-plugin-cc not installed. Install with: claude install gh:stamate/codex-plugin-cc"
- Print: "Falling back to standard review. Use /ai-scientist:review instead."
- **Stop here.**

### 2. Read the Paper

Use the Read tool to read the PDF file at `<pdf_path>`. This extracts the paper content for review.

Also extract text for piping:
```bash
python3 tools/pdf_reader.py <pdf_path>
```

### 3. Run Codex Paper Review

Invoke the Codex paper review command in a single pass. If `--exp-dir` is provided and `--no-alignment` is NOT set, include `--code` to also run code-methods alignment.

**Locate the promoted best solution** (if `--exp-dir` provided and alignment enabled):
```bash
python3 tools/state_manager.py save-best <exp_dir> stage4_ablation 2>/dev/null || \
python3 tools/state_manager.py save-best <exp_dir> stage3_creative 2>/dev/null || \
python3 tools/state_manager.py save-best <exp_dir> stage2_baseline 2>/dev/null || \
python3 tools/state_manager.py save-best <exp_dir> stage1_initial
```
This writes the best node's code and prints the file path. Use the printed directory (e.g., `<exp_dir>/state/stage4_ablation/`) as `<best_solution_dir>`. If all stages fail, skip alignment and log a warning.

**With panel mode + alignment** (default when `--exp-dir` provided):
```
/codex:paper-review <pdf_path> --panel --venue <venue> --code <best_solution_dir> --wait
```
Where `<best_solution_dir>` is the directory containing the best solution file (e.g., `<exp_dir>/state/stage4_ablation/`).

**With panel mode, no alignment** (`--no-alignment` or no `--exp-dir`):
```
/codex:paper-review <pdf_path> --panel --venue <venue> --wait
```

**Without panel mode** (`--no-panel` — no `--venue`, as venue requires panel):
```
/codex:paper-review <pdf_path> --wait
```

**Without panel mode but with alignment** (`--no-panel` + `--exp-dir` provided):
```
/codex:paper-review <pdf_path> --code <best_solution_dir> --wait
```

The Codex plugin returns a structured JSON review with:
- `recommendation`: accept / minor-revision / major-revision / reject
- `summary`, `strengths`, `weaknesses`
- `findings` array with category, severity, section, confidence
- In panel mode: individual reviewer scores + Area Chair synthesis with `consensus_points`, `disagreements`, `aggregated_scores`, `priority_actions`
- If `--code` was used: additional code-methods alignment findings covering hyperparameter mismatches, undocumented preprocessing, data leakage, statistical errors, and missing code

### 5. Save Outputs

The Codex paper-review command returns rendered Markdown, not raw JSON. Save the verbatim output:

```bash
cat > <output_dir>/codex_review.md << 'MD_EOF'
<codex review output — Markdown>
MD_EOF
```

If the output contains structured JSON blocks (e.g., inside code fences), extract them separately:
```bash
cat > <output_dir>/codex_review_structured.json << 'JSON_EOF'
<extracted JSON if present, otherwise omit this file>
JSON_EOF
```

### 6. Merge with Claude Review (if exists)

If a Claude review already exists at `<output_dir>/review.json`, generate a merged summary.

Read the Claude review JSON and parse the Codex review Markdown. Extract key findings from the Codex output and produce:

```json
{
  "claude_review": {
    "overall": "<claude_overall_score>",
    "decision": "<Accept/Reject>",
    "key_strengths": ["..."],
    "key_weaknesses": ["..."]
  },
  "codex_review": {
    "recommendation": "<accept/minor-revision/major-revision/reject>",
    "aggregated_scores": {},
    "key_strengths": ["..."],
    "key_weaknesses": ["..."]
  },
  "consensus": ["Points both reviewers agree on..."],
  "disagreements": ["Points where reviewers diverge..."],
  "code_alignment": {
    "verdict": "<aligned/minor-discrepancies/major-discrepancies>",
    "key_findings": ["..."]
  },
  "combined_recommendation": "<overall assessment considering both reviews>"
}
```

Save to:
```bash
cat > <output_dir>/merged_review.json << 'JSON_EOF'
<merged review JSON>
JSON_EOF
```

### 7. Report Summary

Present:
- Codex panel recommendation and scores
- Top 3 consensus strengths (both reviewers agree)
- Top 3 consensus weaknesses
- Any code-methods alignment issues
- Combined recommendation
