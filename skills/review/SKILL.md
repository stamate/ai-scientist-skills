---
name: review
description: Perform a structured peer review of a research paper — text analysis, figure quality assessment, and NeurIPS-format scoring.
---


# Paper Review

You are an experienced AI researcher performing a rigorous peer review of a research paper.

## Arguments

- `--pdf <path>`: Path to the paper PDF (required)
- `--exp-dir <path>`: Experiment directory (optional, for additional context)
- `--output <path>`: Output directory for review files (default: same as PDF directory)
- `--no-codex`: Skip Codex panel review even if Codex is available
- `--no-scientific-skills`: Skip scientific-critical-thinking assessment even if plugin is available

Parse from the user's message.

## Procedure

### 0. Locate Plugin Root

```bash
export AISCIENTIST_ROOT=$(claude plugin list --json 2>/dev/null | python3 -c "import json,sys;print(next((p['installPath'] for p in json.load(sys.stdin) if 'ai-scientist' in p['id']),''))" 2>/dev/null)
[ -z "$AISCIENTIST_ROOT" ] && echo "ERROR: ai-scientist plugin not found"
echo "Plugin root: $AISCIENTIST_ROOT"
```

### 1. Extract Paper Text

```bash
uv run python3 "$AISCIENTIST_ROOT/tools/pdf_reader.py" <pdf_path>
```

If the paper is long, also extract by sections:
```bash
uv run python3 "$AISCIENTIST_ROOT/tools/pdf_reader.py" <pdf_path> --sections
```

### 2. Load Review Examples

Read few-shot examples to calibrate your review standards:
```bash
cat templates/review_fewshot/attention.json
```

These show what good reviews look like — use them as a reference for depth and specificity, but do NOT copy their content.

### 3. Review the Paper Text

Adopt the following reviewer persona:

> You are an AI researcher reviewing a paper submitted to a prestigious ML venue. Be critical and cautious in your decision. If a paper is bad or you are unsure, give it bad scores and reject it.

Carefully evaluate the paper along these dimensions:

#### Summary
Write a concise summary of the paper's content and contributions. The authors should generally agree with a well-written summary.

#### Strengths
List specific strengths with evidence:
- Is the problem well-motivated?
- Is the approach technically sound?
- Are the experiments comprehensive?
- Are the results significant?

#### Weaknesses
List specific weaknesses with constructive suggestions:
- Are there missing baselines or comparisons?
- Are claims insufficiently supported?
- Are there clarity issues?
- Are there methodological concerns?

### 4. Review Figures (VLM Review)

Read the PDF file to view its pages as images. For each figure in the paper:

1. **Image Description**: What does the figure show?
2. **Image Review**: Is the figure clear, informative, and well-designed?
3. **Caption Review**: Is the caption accurate and complete?
4. **Reference Review**: Is the figure properly referenced and discussed in the text?
5. **Overall Assessment**: Should this figure be in the main paper, moved to appendix, or removed?
6. **Sub-figures**: Are there too many sub-figures? Is the layout effective?
7. **Informativeness**: Does the figure effectively communicate the data?

### 5. Generate Structured Review

Produce the review in this exact JSON format:

```json
{
  "Summary": "A summary of the paper content and its contributions.",
  "Strengths": [
    "Strength 1: specific detail...",
    "Strength 2: specific detail..."
  ],
  "Weaknesses": [
    "Weakness 1: specific detail and suggestion...",
    "Weakness 2: specific detail and suggestion..."
  ],
  "Originality": 3,
  "Quality": 3,
  "Clarity": 3,
  "Significance": 2,
  "Questions": [
    "Question 1: ...",
    "Question 2: ..."
  ],
  "Limitations": [
    "Limitation 1: ...",
    "Limitation 2: ..."
  ],
  "Ethical Concerns": false,
  "Soundness": 3,
  "Presentation": 3,
  "Contribution": 2,
  "Overall": 5,
  "Confidence": 4,
  "Decision": "Accept or Reject"
}
```

#### Scoring Rubric:

**Originality** (1-4): 1=known, 2=minor variation, 3=clear novelty, 4=groundbreaking
**Quality** (1-4): 1=flawed, 2=concerns, 3=solid, 4=excellent
**Clarity** (1-4): 1=unclear, 2=mostly clear, 3=well-written, 4=exemplary
**Significance** (1-4): 1=limited, 2=moderate, 3=important, 4=transformative
**Soundness** (1-4): 1=poor, 2=fair, 3=good, 4=excellent
**Presentation** (1-4): 1=poor, 2=fair, 3=good, 4=excellent
**Contribution** (1-4): 1=poor, 2=fair, 3=good, 4=excellent
**Overall** (1-10): 1=strong reject, 3=reject, 5=borderline, 7=accept, 10=award
**Confidence** (1-5): 1=low, 2=medium, 3=high, 4=very high, 5=absolute

### 6. Generate Figure Review

Create a separate figure-level review:

```json
{
  "figures": [
    {
      "figure_id": "Figure 1",
      "img_description": "...",
      "img_review": "...",
      "caption_review": "...",
      "reference_review": "...",
      "overall_comments": "Keep in main paper / Move to appendix",
      "containing_sub_figures": "Description of sub-figure layout",
      "informative_review": "How effectively the data is communicated"
    }
  ]
}
```

### 7. Save Review Output

Save the text review:
```bash
cat > <output_dir>/review.json << 'JSON_EOF'
<review JSON>
JSON_EOF
```

Save the figure review:
```bash
cat > <output_dir>/review_figures.json << 'JSON_EOF'
<figure review JSON>
JSON_EOF
```

### 8. Report Summary

Present a concise summary:
- Overall score and decision
- Top 3 strengths
- Top 3 weaknesses
- Key recommendation

### 9. Scientific Critical Thinking Assessment (Optional Enhancement)

**Skip this step if** `--no-scientific-skills` is set, plugin not installed, or config disables it.

First, check if the claude-scientific-skills plugin is actually installed:
```bash
claude plugin list --json 2>/dev/null | python3 -c "import json,sys;any('sci-skills' in p['id'] for p in json.load(sys.stdin)) and print('SCIENTIFIC_PLUGIN_OK') or print('SCIENTIFIC_PLUGIN_MISSING')" 2>/dev/null
```
If `SCIENTIFIC_PLUGIN_MISSING`, skip this entire step silently.

Then check config (if `--exp-dir` is provided):
```bash
uv run python3 -c "
import yaml, os, sys; sys.path.insert(0, os.environ.get('AISCIENTIST_ROOT', '.'))
try:
    cfg = yaml.safe_load(open('<exp_dir>/config.yaml'))
    enabled = str(cfg.get('scientific_skills', {}).get('enabled', 'auto')).lower()
    review = cfg.get('scientific_skills', {}).get('enhanced_review', True)
    print(f'enabled={enabled} enhanced_review={review}')
except: print('enabled=auto enhanced_review=True')
" 2>/dev/null
```
If `enabled` is `false` or `enhanced_review` is `false`, skip this step.

When enabled, augment the review with a rigorous evidence quality assessment:

1. **Invoke scientific critical thinking**:
   ```
   /scientific-critical-thinking
   ```
   Provide the paper text and ask it to evaluate:
   - **Methodology critique**: Is the study design appropriate? Are controls adequate? Is there selection bias?
   - **Statistical evaluation**: Are tests appropriate? Are multiple comparisons corrected? Are effect sizes reported?
   - **Evidence quality**: Using GRADE framework, rate the quality of evidence (High/Moderate/Low/Very Low)
   - **Logical fallacy detection**: Check for correlation-causation confusion, hasty generalization, cherry-picking, survivorship bias
   - **Bias assessment**: Identify potential cognitive, selection, measurement, and analysis biases

2. **Save the assessment**:
   ```bash
   cat > <output_dir>/evidence_assessment.md << 'MD_EOF'
   <critical thinking assessment output>
   MD_EOF
   ```

3. **Integrate findings** into the review summary:
   - Add evidence quality grade alongside overall score
   - Flag any logical fallacies or methodological concerns
   - Note bias risks that may affect interpretation

This assessment adds scientific rigor to the review without changing the NeurIPS-format scores from steps 1-8.

### 10. Codex Panel Review (Optional Enhancement)

**Skip this step if** Codex is not available, the user specified `--no-codex`, or `codex.enabled` is `"false"` in config.

Check Codex availability (CLI + plugin + auth):
```bash
which codex 2>/dev/null && echo "CLI_OK" || echo "CLI_MISSING"
claude plugin list --json 2>/dev/null | python3 -c "import json,sys;any('codex' in p['id'] for p in json.load(sys.stdin)) and print('PLUGIN_OK') or print('PLUGIN_MISSING')" 2>/dev/null
codex login status 2>/dev/null && echo "AUTH_OK" || echo "AUTH_MISSING"
```
All three must succeed. If any fails, skip this step silently.

If `CODEX_AVAILABLE`, enhance the review with a Codex panel:

1. **Read Codex config values** from the experiment's config (if `--exp-dir` provided):
   ```bash
   uv run python3 "$AISCIENTIST_ROOT/tools/config.py" --config <exp_dir>/config.yaml 2>/dev/null
   ```
   Extract:
   - `codex.enabled` — if `"false"`, **skip this entire step** even if the CLI is on PATH
   - `codex.venue` — if `"auto"`, derive from `writeup_type` (icbinb→workshop, icml→icml). Otherwise use the configured value.
   - `codex.panel_paper_review` — if `false`, omit `--panel` flag
   - `codex.code_alignment` — if `false`, omit `--code` flag even when `--exp-dir` is provided

   If no config available, use defaults: enabled=`"auto"`, venue=`workshop`, panel=`true`, alignment=`true`.

2. **Run Codex review** (respecting config toggles):

   If `codex.code_alignment` is `true` and `--exp-dir` is provided, save the promoted best solution to a known path and use that:
   ```bash
   uv run python3 "$AISCIENTIST_ROOT/tools/state_manager.py" save-best <exp_dir> stage4_ablation 2>/dev/null || \
   uv run python3 "$AISCIENTIST_ROOT/tools/state_manager.py" save-best <exp_dir> stage3_creative 2>/dev/null || \
   uv run python3 "$AISCIENTIST_ROOT/tools/state_manager.py" save-best <exp_dir> stage2_baseline 2>/dev/null || \
   uv run python3 "$AISCIENTIST_ROOT/tools/state_manager.py" save-best <exp_dir> stage1_initial
   ```
   This writes `best_solution_<id>.py` to the stage's state directory and prints the file path. Use the printed directory (e.g., `<exp_dir>/state/stage4_ablation/`) as `<best_solution_dir>`.

   If `save-best` fails for all stages (no good nodes in any stage), skip code-methods alignment and log a warning.

   Build the command based on config flags:
   - Start with: `/codex:paper-review <pdf_path>`
   - Add `--panel --venue <venue>` only if `codex.panel_paper_review` is `true` (venue requires panel)
   - Add `--code <best_solution_dir>` only if alignment is enabled AND `--exp-dir` was provided AND `save-best` succeeded
   - Add `--wait`

   Example (all features enabled):
   ```
   /codex:paper-review <pdf_path> --panel --venue <venue> --code <best_solution_dir> --wait
   ```

   Example (panel disabled, alignment disabled — single reviewer, no venue):
   ```
   /codex:paper-review <pdf_path> --wait
   ```

3. **Save Codex outputs** (Codex returns rendered Markdown, not raw JSON):
   ```bash
   cat > <output_dir>/codex_review.md << 'MD_EOF'
   <codex review output — Markdown>
   MD_EOF
   ```

4. **Report Codex additions** alongside the Claude review:
   - Codex panel recommendation and aggregated scores
   - Any code-methods alignment issues found
   - Note: The Claude review (steps 1-8) is the primary review; Codex adds a second opinion

If Codex is not available, skip silently — the Claude review from steps 1-8 is complete on its own.

## Review Standards

- Be **specific** — point to exact sections, figures, or claims
- Be **constructive** — every weakness should suggest a fix
- Be **fair** — consider the paper's intended scope and venue
- Be **calibrated** — use the few-shot examples as anchors
- For automated AI research papers, pay special attention to:
  - Whether experiments are run on real data (not synthetic)
  - Whether results are reproducible from the described methodology
  - Whether the paper correctly distinguishes what was automated vs. human-guided
