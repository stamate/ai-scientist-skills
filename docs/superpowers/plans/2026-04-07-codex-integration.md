# Codex Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate codex-plugin-cc capabilities into stamate/ai-scientist-skills to enhance paper review (Codex panel mode + venue calibration), experiment code review (adversarial review between BFTS stages), code-methods alignment checking, and rescue delegation for stuck experiments. All features optional — gracefully degrade when Codex is not installed.

**Architecture:** Both plugins are installed in Claude Code. The ai-scientist skills invoke Codex commands via the Skill tool (`/codex:paper-review`, `/codex:adversarial-review`, `/codex:rescue`). A `check_codex()` function in verify_setup.py detects availability. A `CodexConfig` dataclass in config.py controls which features are enabled. Skills check Codex availability at runtime and skip gracefully when absent.

**Tech Stack:** Claude Code skills (SKILL.md prompts), Python 3.11+ (dataclasses, shutil, subprocess), YAML config, codex-plugin-cc (Node.js companion script invoked via Claude Code Skill tool)

---

## File Structure

| Action | File | Responsibility |
|--------|------|---------------|
| Create | `skills/codex-review/SKILL.md` | Codex-enhanced paper review: panel mode, venue calibration, code-methods alignment |
| Modify | `tools/config.py` | Add `CodexConfig` dataclass with feature toggles |
| Modify | `tools/verify_setup.py` | Add `check_codex()` function to detect Codex CLI |
| Modify | `templates/bfts_config.yaml` | Add `codex:` section with defaults |
| Modify | `.claude/settings.json` | Register new `ai-scientist:codex-review` skill |
| Modify | `skills/review/SKILL.md` | Add optional Codex panel review after Claude review |
| Modify | `skills/experiment/SKILL.md` | Add stage-gate adversarial code review between stages |
| Modify | `skills/ai-scientist/SKILL.md` | Add Codex detection in Phase 0, wire codex-review in Phase 6 |
| Modify | `CLAUDE.md` | Document new skill and Codex integration |
| Modify | `README.md` | Document Codex features and install instructions |

---

### Task 1: Add CodexConfig to config system

**Files:**
- Modify: `tools/config.py:18-96`
- Modify: `templates/bfts_config.yaml:66-67`

- [ ] **Step 1: Add CodexConfig dataclass to config.py**

Insert the new dataclass after `ExperimentConfig` (line 52) and before `Config` (line 55):

```python
@dataclass
class CodexConfig:
    enabled: str = "auto"  # "auto" | "true" | "false"
    stage_gate_review: bool = True
    panel_paper_review: bool = True
    code_alignment: bool = True
    rescue_on_stuck: bool = True
    venue: str = "auto"  # "auto" | "neurips" | "icml" | "iclr" | "workshop"
```

- [ ] **Step 2: Add codex field to Config dataclass**

In the `Config` class, after the `skip_review` field (line 95), add:

```python
    # Codex integration (optional)
    codex: CodexConfig = field(default_factory=CodexConfig)
```

- [ ] **Step 3: Add codex section to bfts_config.yaml**

Append after `skip_review: false` (line 67):

```yaml

# ── Codex integration (optional — requires codex-plugin-cc) ─────────────────
codex:
  enabled: auto              # auto (use if available) | true | false
  stage_gate_review: true    # adversarial code review between BFTS stages
  panel_paper_review: true   # Codex panel review of final paper
  code_alignment: true       # code-methods alignment check (paper vs code)
  rescue_on_stuck: true      # delegate to Codex when experiments are stuck
  venue: auto                # auto (from writeup_type) | neurips | icml | iclr | workshop
```

- [ ] **Step 4: Verify config loads correctly**

Run:
```bash
cd /Users/c/lab/plugins/ai-scientist-skills && python3 tools/config.py
```
Expected: YAML output includes `codex:` section with all default values. No errors.

- [ ] **Step 5: Verify config override works**

Run:
```bash
cd /Users/c/lab/plugins/ai-scientist-skills && python3 tools/config.py --set codex.enabled=false codex.venue=neurips
```
Expected: Output shows `codex.enabled: false` and `codex.venue: neurips`.

- [ ] **Step 6: Commit**

```bash
cd /Users/c/lab/plugins/ai-scientist-skills && git add tools/config.py templates/bfts_config.yaml && git commit -m "feat: add CodexConfig dataclass and YAML defaults for Codex integration"
```

---

### Task 2: Add Codex check to verify_setup.py

**Files:**
- Modify: `tools/verify_setup.py:154-215`

- [ ] **Step 1: Add check_codex function**

Insert after `check_claude_code()` (after line 161) and before `main()` (line 164):

```python
def check_codex() -> bool:
    """Check if Codex CLI is installed (optional enhancement)."""
    codex = shutil.which("codex")
    if codex:
        print(f"  {CHECK} Codex CLI ({codex}) — enhanced reviews available")
        return True
    else:
        print(f"  {WARN} Codex CLI not found — standard pipeline only (optional)")
        print(f"      Install: npm install -g @openai/codex")
        return False
```

- [ ] **Step 2: Add Codex section to main()**

In `main()`, after the Claude Code section (after line 203), add a new section:

```python
    # Codex (optional enhancement)
    print("\n[Codex Integration (optional)]")
    if not check_codex():
        warnings += 1
```

- [ ] **Step 3: Verify setup script runs**

Run:
```bash
cd /Users/c/lab/plugins/ai-scientist-skills && python3 tools/verify_setup.py
```
Expected: Output includes `[Codex Integration (optional)]` section. Shows either check mark or warning. No errors. Exit code 0 (Codex is optional, so missing = warning, not error).

- [ ] **Step 4: Commit**

```bash
cd /Users/c/lab/plugins/ai-scientist-skills && git add tools/verify_setup.py && git commit -m "feat: add optional Codex CLI check to verify_setup.py"
```

---

### Task 3: Create codex-review skill

**Files:**
- Create: `skills/codex-review/SKILL.md`

- [ ] **Step 1: Create the skill directory**

```bash
mkdir -p /Users/c/lab/plugins/ai-scientist-skills/skills/codex-review
```

- [ ] **Step 2: Write the codex-review SKILL.md**

Create `skills/codex-review/SKILL.md` with this content:

```markdown
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

```bash
which codex 2>/dev/null && echo "CODEX_AVAILABLE" || echo "CODEX_NOT_AVAILABLE"
```

If `CODEX_NOT_AVAILABLE`:
- Print: "Codex CLI not found. Install with: npm install -g @openai/codex"
- Print: "Falling back to standard review. Use /ai-scientist:review instead."
- **Stop here.** Do not proceed.

### 2. Read the Paper

Use the Read tool to read the PDF file at `<pdf_path>`. This extracts the paper content for review.

Also extract text for piping:
```bash
python3 tools/pdf_reader.py <pdf_path>
```

### 3. Run Codex Paper Review

Invoke the Codex paper review command. Build the arguments:

**With panel mode** (default):
```
/codex:paper-review <pdf_path> --panel --venue <venue> --wait
```

**Without panel mode** (`--no-panel`):
```
/codex:paper-review <pdf_path> --venue <venue> --wait
```

Wait for the review to complete. The Codex plugin returns a structured JSON review with:
- `recommendation`: accept / minor-revision / major-revision / reject
- `summary`, `strengths`, `weaknesses`
- `findings` array with category, severity, section, confidence
- In panel mode: individual reviewer scores + Area Chair synthesis with `consensus_points`, `disagreements`, `aggregated_scores`, `priority_actions`

### 4. Run Code-Methods Alignment (Optional)

**Skip if** `--no-alignment` is set or `--exp-dir` is not provided.

If experiment directory is available, run Codex code-methods alignment by invoking the paper review with the `--code` flag:

```
/codex:paper-review <pdf_path> --venue <venue> --code <exp_dir>/workspace --wait
```

This produces an alignment check covering:
- Hyperparameter mismatches between paper and code
- Undocumented preprocessing steps
- Data leakage risks
- Statistical implementation errors
- Missing code for described methods

### 5. Save Outputs

Save the Codex panel review:
```bash
cat > <output_dir>/codex_review.json << 'JSON_EOF'
<codex review JSON>
JSON_EOF
```

If code-methods alignment was run, save it:
```bash
cat > <output_dir>/code_alignment.json << 'JSON_EOF'
<alignment JSON>
JSON_EOF
```

### 6. Merge with Claude Review (if exists)

If a Claude review already exists at `<output_dir>/review.json`, generate a merged summary:

Read both reviews and produce:

```json
{
  "claude_review": {
    "overall": <claude_overall_score>,
    "decision": "<Accept/Reject>",
    "key_strengths": ["..."],
    "key_weaknesses": ["..."]
  },
  "codex_review": {
    "recommendation": "<accept/minor-revision/major-revision/reject>",
    "aggregated_scores": { ... },
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
```

- [ ] **Step 3: Register the new skill in settings.json**

In `.claude/settings.json`, add after the `ai-scientist:review` entry (after line 29):

```json
    "ai-scientist:codex-review": {
      "type": "prompt",
      "path": "skills/codex-review/SKILL.md"
    },
```

- [ ] **Step 4: Verify skill file exists and is valid**

```bash
cat /Users/c/lab/plugins/ai-scientist-skills/skills/codex-review/SKILL.md | head -5
```
Expected: Shows the frontmatter with `name: codex-review`.

```bash
cd /Users/c/lab/plugins/ai-scientist-skills && python3 -c "import json; d=json.load(open('.claude/settings.json')); assert 'ai-scientist:codex-review' in d['skills']; print('OK')"
```
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
cd /Users/c/lab/plugins/ai-scientist-skills && git add skills/codex-review/SKILL.md .claude/settings.json && git commit -m "feat: add codex-review skill for Codex panel paper review with code-methods alignment"
```

---

### Task 4: Modify review skill with optional Codex panel enhancement

**Files:**
- Modify: `skills/review/SKILL.md:148-182`

- [ ] **Step 1: Add Codex enhancement section to review skill**

After "### 8. Report Summary" section (after line 170) and before "## Review Standards" (line 172), insert a new section:

```markdown

### 9. Codex Panel Review (Optional Enhancement)

**Skip this step if** Codex is not available or the user specified `--no-codex`.

Check Codex availability:
```bash
which codex 2>/dev/null && echo "CODEX_AVAILABLE" || echo "CODEX_NOT_AVAILABLE"
```

If `CODEX_AVAILABLE`, enhance the review with a Codex panel:

1. **Determine venue** from context:
   - If experiment used `writeup_type: icbinb` → venue = `workshop`
   - If experiment used `writeup_type: icml` → venue = `icml`
   - Default: `workshop`

2. **Run Codex panel review**:
   ```
   /codex:paper-review <pdf_path> --panel --venue <venue> --wait
   ```

3. **Run code-methods alignment** (if `--exp-dir` provided):
   ```
   /codex:paper-review <pdf_path> --venue <venue> --code <exp_dir>/workspace --wait
   ```

4. **Save Codex outputs**:
   ```bash
   cat > <output_dir>/codex_review.json << 'JSON_EOF'
   <codex review JSON>
   JSON_EOF
   ```

5. **Report Codex additions** alongside the Claude review:
   - Codex panel recommendation and aggregated scores
   - Any code-methods alignment issues found
   - Note: The Claude review (steps 1-8) is the primary review; Codex adds a second opinion

If Codex is not available, skip silently — the Claude review from steps 1-8 is complete on its own.

```

- [ ] **Step 2: Add --no-codex argument**

In the Arguments section (line 14), add:

```markdown
- `--no-codex`: Skip Codex panel review even if Codex is available
```

- [ ] **Step 3: Verify the file is valid markdown**

```bash
wc -l /Users/c/lab/plugins/ai-scientist-skills/skills/review/SKILL.md
```
Expected: Line count increased (was 182, now ~220+).

- [ ] **Step 4: Commit**

```bash
cd /Users/c/lab/plugins/ai-scientist-skills && git add skills/review/SKILL.md && git commit -m "feat: add optional Codex panel review enhancement to review skill"
```

---

### Task 5: Modify experiment skill with stage-gate adversarial review

**Files:**
- Modify: `skills/experiment/SKILL.md:141-164`

- [ ] **Step 1: Add stage-gate review section**

After the "d. Stage Transition" subsection (after line 163, before "### 6. Post-Experiment"), insert a new subsection:

```markdown

#### e. Stage-Gate Code Review (Optional — Codex)

**Skip if** Codex is not available or `codex.stage_gate_review` is `false` in config.

After completing a stage transition and before starting the next stage, optionally run an adversarial code review on the best node's code to catch subtle issues.

1. **Check Codex availability**:
   ```bash
   which codex 2>/dev/null && echo "CODEX_AVAILABLE" || echo "CODEX_NOT_AVAILABLE"
   ```

2. **If available**, get the best node's code and ask Codex to review it:
   ```
   /codex:rescue --wait "Adversarial code review of this ML experiment script. Check for: (1) data leakage between train/test splits, (2) incorrect metric computation, (3) device handling errors, (4) numerical instability (NaN/Inf), (5) unreproducible randomness, (6) silent failures in data loading, (7) incorrect loss function usage. Code path: <exp_dir>/workspace/runfile.py"
   ```

3. **If critical issues found** (data leakage, incorrect metrics, statistical errors):
   - Add the findings to the stage briefing under a new `"code_review_issues"` key
   - The next stage's agents should address these issues as a priority
   - Print warning: "Codex found critical code issues — flagged in stage briefing"

4. **If no issues or only minor issues**:
   - Note in stage briefing under `"code_review_issues": "No critical issues found"`
   - Proceed normally

This step typically adds 1-3 minutes per stage transition but can prevent wasted iterations in subsequent stages.

```

- [ ] **Step 2: Add rescue for stuck experiments section**

After the new "e. Stage-Gate Code Review" section, add:

```markdown

#### f. Rescue for Stuck Experiments (Optional — Codex)

**Skip if** Codex is not available or `codex.rescue_on_stuck` is `false` in config.

If Stage 1 has used 80%+ of `stage1_max_iters` with zero good nodes, delegate diagnosis to Codex:

1. **Collect recent error information**:
   ```bash
   python3 tools/state_manager.py journal-summary <exp_dir> stage1_initial
   ```
   Note the total nodes, buggy count, and the last few error types.

2. **Invoke Codex rescue**:
   ```
   /codex:rescue --wait "ML experiment is failing repeatedly. After <N> iterations, zero experiments produce valid metrics. Common errors: <list last 2-3 error types/messages>. The research goal is: <task_desc>. Experiment code is at: <exp_dir>/workspace/runfile.py. Diagnose the root cause and suggest a concrete fix approach."
   ```

3. **Use the diagnosis** to inform the next draft/debug action. Include Codex's recommendations in the task description for the next experiment-step agent.

This is a last-resort mechanism — it only triggers when the BFTS tree is failing to produce any working code.

```

- [ ] **Step 3: Verify the file structure**

```bash
grep -n "^####" /Users/c/lab/plugins/ai-scientist-skills/skills/experiment/SKILL.md
```
Expected: Shows sections a through f in the Execute Stages section.

- [ ] **Step 4: Commit**

```bash
cd /Users/c/lab/plugins/ai-scientist-skills && git add skills/experiment/SKILL.md && git commit -m "feat: add Codex stage-gate adversarial review and rescue for stuck experiments"
```

---

### Task 6: Modify orchestrator with Codex integration

**Files:**
- Modify: `skills/ai-scientist/SKILL.md`

- [ ] **Step 1: Add --use-codex and --no-codex arguments**

In the Arguments section (after line 21, after `--seed-code`), add:

```markdown
- `--use-codex`: Force enable Codex integration (even if auto-detection fails)
- `--no-codex`: Force disable Codex integration (even if Codex is installed)
```

- [ ] **Step 2: Add Codex detection to Phase 0**

After step 4 (Check LaTeX, line 63), add a new step 5:

```markdown

5. **Detect Codex** (optional enhancement):
   ```bash
   which codex 2>/dev/null && echo "CODEX_AVAILABLE" || echo "CODEX_NOT_AVAILABLE"
   ```
   - If `CODEX_AVAILABLE` and not `--no-codex`: print "Codex detected — enhanced reviews enabled"
   - If `--use-codex` but not available: warn "Codex requested but not found — install with: npm install -g @openai/codex"
   - If not available and not `--use-codex`: print "Codex not found — using standard pipeline (install codex-plugin-cc for enhanced reviews)"
   - Store result as `CODEX_ENABLED` (true/false) for later phases
```

- [ ] **Step 3: Update Phase 6 to offer Codex-enhanced review**

Replace the Phase 6 section (lines 136-145) with:

```markdown
### Phase 6: Paper Review

**Skip if** `--skip-review` is set, or if no PDF was generated.

**If `CODEX_ENABLED`**:

Run both the Claude review and Codex panel review for comprehensive assessment:
```
/ai-scientist:review --pdf <exp_dir>/paper.pdf --exp-dir <exp_dir>
```
The review skill will automatically invoke Codex panel review if available (see Step 9 in the review skill).

Additionally, run the dedicated Codex review for panel synthesis and code-methods alignment:
```
/ai-scientist:codex-review --pdf <exp_dir>/paper.pdf --exp-dir <exp_dir> --venue <mapped_venue>
```

Venue mapping:
- `--type icbinb` → `--venue workshop`
- `--type icml` → `--venue icml`

**If NOT `CODEX_ENABLED`**:

Run the standard Claude review:
```
/ai-scientist:review --pdf <exp_dir>/paper.pdf --exp-dir <exp_dir>
```
```

- [ ] **Step 4: Update Phase 7 Summary to include Codex**

In the summary report (around line 168), after the Review section, add:

```markdown
    Codex Review: <exp_dir>/codex_review.json (if available)
      Panel:       <recommendation> (Empiricist/Theorist/Practitioner consensus)
      Alignment:   <aligned/minor-discrepancies/major-discrepancies>
```

- [ ] **Step 5: Verify file structure**

```bash
grep -n "Phase" /Users/c/lab/plugins/ai-scientist-skills/skills/ai-scientist/SKILL.md
```
Expected: All phases (0 through 7) present, Phase 0 includes Codex detection, Phase 6 has conditional Codex path.

- [ ] **Step 6: Commit**

```bash
cd /Users/c/lab/plugins/ai-scientist-skills && git add skills/ai-scientist/SKILL.md && git commit -m "feat: wire Codex integration into orchestrator — detection, enhanced review, summary"
```

---

### Task 7: Update documentation (CLAUDE.md and README.md)

**Files:**
- Modify: `CLAUDE.md`
- Modify: `README.md`

- [ ] **Step 1: Update CLAUDE.md skills table**

In CLAUDE.md, after the `/ai-scientist:workshop` row in the skills table, add:

```markdown
| `/ai-scientist:codex-review` | Codex panel paper review with code-methods alignment (optional) |
```

- [ ] **Step 2: Add Codex section to CLAUDE.md**

After the "## Experiment Code Conventions" section at the end of CLAUDE.md, append:

```markdown

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
```

- [ ] **Step 3: Update README.md Skills Reference**

In README.md, after the "### Writing & Review" table (around line 188), add a new row:

```markdown
| Optional | `/ai-scientist:codex-review` | Codex panel review + code-methods alignment (requires codex-plugin-cc). |
```

- [ ] **Step 4: Add Codex Integration section to README.md**

After the "### Environment Variables" table (around line 293), add a new section:

```markdown

### Codex Integration (Optional)

Install the [codex-plugin-cc](https://github.com/stamate/codex-plugin-cc) plugin for enhanced reviews:

```bash
claude install gh:stamate/codex-plugin-cc
npm install -g @openai/codex
codex login
```

When Codex is available, the pipeline automatically:
- Runs **panel paper review** with 3 personas (Empiricist, Theorist, Practitioner) + Area Chair synthesis
- Performs **code-methods alignment** checking (paper claims vs. actual code)
- Adds **adversarial code review** between BFTS experiment stages
- Delegates **stuck experiment diagnosis** to Codex when Stage 1 fails

Disable with `--no-codex` or in config:
```yaml
codex:
  enabled: false
```
```

- [ ] **Step 5: Update Comparison table in README.md**

In the comparison table (around line 306), add a new row after "Review format":

```markdown
| Enhanced review | — | Optional Codex panel (3 personas + synthesis) |
```

- [ ] **Step 6: Verify documentation**

```bash
grep -c "codex" /Users/c/lab/plugins/ai-scientist-skills/CLAUDE.md
grep -c "codex" /Users/c/lab/plugins/ai-scientist-skills/README.md
```
Expected: Both files show non-zero counts for "codex" mentions.

- [ ] **Step 7: Commit**

```bash
cd /Users/c/lab/plugins/ai-scientist-skills && git add CLAUDE.md README.md && git commit -m "docs: document Codex integration features and install instructions"
```

---

## Verification Checklist

After all tasks complete, verify the integration end-to-end:

- [ ] `python3 tools/verify_setup.py` — shows Codex section (check or warning)
- [ ] `python3 tools/config.py` — shows `codex:` section with all fields
- [ ] `python3 tools/config.py --set codex.enabled=false` — override works
- [ ] `.claude/settings.json` contains 10 skills (9 original + codex-review)
- [ ] `skills/codex-review/SKILL.md` exists with valid frontmatter
- [ ] `skills/review/SKILL.md` contains "Codex Panel Review" section
- [ ] `skills/experiment/SKILL.md` contains "Stage-Gate Code Review" and "Rescue" sections
- [ ] `skills/ai-scientist/SKILL.md` contains Codex detection and conditional Phase 6
- [ ] `CLAUDE.md` documents the new skill and Codex integration
- [ ] `README.md` includes install instructions and feature description
- [ ] All commits have clean messages following Conventional Commits
