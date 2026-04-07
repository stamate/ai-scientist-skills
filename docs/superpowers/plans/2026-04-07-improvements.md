# AI Scientist Skills Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement 9 improvements across 3 tiers: uv migration + multi-seed + dry-run + pre-commit (infrastructure), split experiment-step + structured logs + dedup + parallel lit search + budget estimator (pipeline), and review feedback loop with configurable passes (review).

**Architecture:** All Python invocations migrate from `python3` to `uv run python3`. New Python tools follow the existing CLI pattern (`uv run python3 tools/<module>.py`). New skills follow the SKILL.md prompt pattern. Config additions use the established dataclass + YAML pattern.

**Tech Stack:** Python 3.11+ (via uv), PyTorch, YAML config, Claude Code skills (SKILL.md prompts)

---

## Plan A: Core Infrastructure

### Task 1: Migrate all `python3` to `uv run python3`

**Files:**
- Modify: `CLAUDE.md` (18 occurrences)
- Modify: `README.md` (2 occurrences)
- Modify: `skills/ai-scientist/SKILL.md` (7 occurrences)
- Modify: `skills/experiment/SKILL.md` (24 occurrences)
- Modify: `skills/experiment-step/SKILL.md` (8 occurrences)
- Modify: `skills/ideation/SKILL.md` (3 occurrences)
- Modify: `skills/review/SKILL.md` (7 occurrences)
- Modify: `skills/writeup/SKILL.md` (6 occurrences)
- Modify: `skills/plot/SKILL.md` (2 occurrences)
- Modify: `skills/codex-review/SKILL.md` (4 occurrences)
- Modify: `skills/lit-search/SKILL.md` (1 occurrence)
- Modify: `tools/state_manager.py` (8 occurrences in docstrings)

- [ ] **Step 1: Bulk replace in all skill files**

Run from project root:
```bash
find skills/ -name "SKILL.md" -exec sed -i '' 's|python3 tools/|uv run python3 tools/|g' {} \;
find skills/ -name "SKILL.md" -exec sed -i '' 's|python3 -c|uv run python3 -c|g' {} \;
find skills/ -name "SKILL.md" -exec sed -i '' 's|timeout 3600 python3|timeout 3600 uv run python3|g' {} \;
```

- [ ] **Step 2: Update CLAUDE.md**

Replace all `python3 tools/` with `uv run python3 tools/` in the Tool Usage section. Also update the text that says "All tools are invoked via `python3 tools/<module>.py`" to say "All tools are invoked via `uv run python3 tools/<module>.py`".

- [ ] **Step 3: Update README.md**

Replace `python3 tools/verify_setup.py` with `uv run python3 tools/verify_setup.py`. Update the "All tools are invoked via" text.

- [ ] **Step 4: Update state_manager.py docstrings**

Replace `python3 tools/` with `uv run python3 tools/` in the CLI usage docstrings (lines 593-600).

- [ ] **Step 5: Special case — experiment runfile execution**

In `skills/experiment/SKILL.md` and `skills/experiment-step/SKILL.md`, the experiment code itself (`runfile.py`) should also run via uv:
- Change `timeout 3600 python3 runfile.py` to `timeout 3600 uv run python3 runfile.py`

- [ ] **Step 6: Verify no bare python3 remains**

```bash
grep -rn "python3" skills/ tools/state_manager.py CLAUDE.md README.md | grep -v "uv run python3" | grep -v "# " | grep -v "tell the user"
```
Expected: No matches (except comments and the "tell the user" text in ai-scientist/SKILL.md).

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat: migrate all python3 invocations to uv run python3"
```

---

### Task 2: Multi-seed via environment variable

**Files:**
- Modify: `tools/device_utils.py`
- Modify: `skills/experiment/SKILL.md` (multi-seed section)
- Modify: `skills/experiment-step/SKILL.md` (code requirements)

- [ ] **Step 1: Update get_device_preamble() in device_utils.py**

Change the seed block from hardcoded `42` to read from `SEED` env var:

```python
# In the preamble string, replace:
#   torch.manual_seed(42)
# With:
import random
import numpy as np

SEED = int(os.environ.get("SEED", "42"))
torch.manual_seed(SEED)
if DEVICE.type == "cuda":
    torch.cuda.manual_seed_all(SEED)
np.random.seed(SEED)
random.seed(SEED)
print(f"Random seed: {SEED}")
```

- [ ] **Step 2: Update multi-seed evaluation in experiment/SKILL.md**

Replace the `sed`-based seed swapping (step 5c) with env var approach:

```bash
for seed in 42 123 456; do
    cd <exp_dir>/workspace && SEED=$seed timeout 3600 uv run python3 runfile.py 2>&1 | tee <exp_dir>/logs/seed_${seed}_output.txt
done
```

Remove the `sed "s/torch.manual_seed(42)/torch.manual_seed($seed)/"` line and the `runfile_seed_$seed.py` pattern.

- [ ] **Step 3: Update experiment-step code requirements**

In experiment-step/SKILL.md, update the code requirements section to mention that the preamble reads `SEED` from env, so experiment code inherits reproducibility automatically.

- [ ] **Step 4: Verify**

```bash
grep -n "SEED" tools/device_utils.py
grep -n "sed.*manual_seed" skills/experiment/SKILL.md
```
Expected: SEED env var in device_utils.py; no sed-based seed swapping in experiment.

- [ ] **Step 5: Commit**

```bash
git add tools/device_utils.py skills/experiment/SKILL.md skills/experiment-step/SKILL.md && git commit -m "feat: multi-seed via SEED env var instead of fragile sed replacement"
```

---

### Task 3: Dry-run mode

**Files:**
- Modify: `skills/ai-scientist/SKILL.md` (add --dry-run argument and phase)
- Modify: `tools/verify_setup.py` (add --dry-run extended checks)

- [ ] **Step 1: Add --dry-run to orchestrator arguments**

In skills/ai-scientist/SKILL.md, add to the Arguments section:
```markdown
- `--dry-run`: Validate environment and config without running experiments. Reports readiness status and estimated token budget.
```

- [ ] **Step 2: Add dry-run phase to orchestrator**

After Phase 0 (Setup) and before Phase 0.5, add:

```markdown
### Dry-Run Check

**Only if** `--dry-run` is set. After Phase 0 completes, perform extended validation and stop:

1. Report all Phase 0 results (environment, device, config, LaTeX, Codex, scientific skills)
2. If `--workshop` provided, validate the workshop file has required sections (Title, Keywords, TL;DR, Abstract)
3. If `--idea` provided, validate the idea JSON has required fields per `templates/idea_schema.json`
4. Test S2 API connectivity:
   ```bash
   uv run python3 tools/search.py check
   ```
5. Test LaTeX compilation with a minimal document:
   ```bash
   uv run python3 tools/latex_compiler.py check
   ```
6. Report estimated token budget (if budget_estimator.py exists):
   ```bash
   uv run python3 tools/budget_estimator.py --config <config_path> 2>/dev/null || echo "Budget estimator not available"
   ```
7. Print summary:
   ```
   ═══════════════════════════════════════════════════════
     AI Scientist Dry Run — Validation Complete
   ═══════════════════════════════════════════════════════
     Environment:    ✓ Ready
     Workshop:       ✓ Valid (or N/A)
     Config:         ✓ Loaded (<N> stages, <N> max iters)
     LaTeX:          ✓ Available (or ✗ Missing)
     S2 API:         ✓ Connected (or ! Fallback to WebSearch)
     Codex:          ✓ Enabled (or — Disabled)
     Scientific:     ✓ Enabled (or — Disabled)
   ═══════════════════════════════════════════════════════
   ```
8. **Stop here.** Do not proceed to Phase 0.5 or beyond.
```

- [ ] **Step 3: Commit**

```bash
git add skills/ai-scientist/SKILL.md && git commit -m "feat: add --dry-run mode for environment validation without execution"
```

---

### Task 4: Pre-commit validation hook

**Files:**
- Create: `scripts/pre-commit-check.py`
- Modify: `CLAUDE.md` (document the hook)

- [ ] **Step 1: Create pre-commit check script**

Create `scripts/pre-commit-check.py`:

```python
# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml"]
# ///
"""Pre-commit validation for ai-scientist-skills.

Usage: uv run scripts/pre-commit-check.py
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

errors = []

# 1. Validate all SKILL.md files have valid frontmatter
for skill_md in Path("skills").rglob("SKILL.md"):
    text = skill_md.read_text()
    if not text.startswith("---"):
        errors.append(f"{skill_md}: missing frontmatter (must start with ---)")
        continue
    parts = text.split("---", 2)
    if len(parts) < 3:
        errors.append(f"{skill_md}: malformed frontmatter (no closing ---)")
        continue
    fm = parts[1].strip()
    if "name:" not in fm:
        errors.append(f"{skill_md}: frontmatter missing 'name:' field")
    if "description:" not in fm:
        errors.append(f"{skill_md}: frontmatter missing 'description:' field")

# 2. Validate settings.json matches skill directories
settings_path = Path(".claude/settings.json")
if settings_path.exists():
    settings = json.loads(settings_path.read_text())
    for name, info in settings.get("skills", {}).items():
        skill_path = Path(info["path"])
        if not skill_path.exists():
            errors.append(f"settings.json: skill '{name}' points to missing {skill_path}")

# 3. Validate bfts_config.yaml parses
config_path = Path("templates/bfts_config.yaml")
if config_path.exists():
    import yaml
    try:
        cfg = yaml.safe_load(config_path.read_text())
        if not isinstance(cfg, dict):
            errors.append("bfts_config.yaml: does not parse to a dict")
    except yaml.YAMLError as e:
        errors.append(f"bfts_config.yaml: YAML parse error: {e}")

# 4. Check step numbering in SKILL.md files
for skill_md in Path("skills").rglob("SKILL.md"):
    text = skill_md.read_text()
    import re
    headers = re.findall(r"^### (\d+)\.", text, re.MULTILINE)
    if headers:
        nums = [int(h) for h in headers]
        for i in range(1, len(nums)):
            if nums[i] != nums[i-1] + 1:
                errors.append(f"{skill_md}: step numbering gap: {nums[i-1]} → {nums[i]}")

# 5. Check marketplace.json lists all skills from settings.json
marketplace_path = Path(".claude-plugin/marketplace.json")
if marketplace_path.exists() and settings_path.exists():
    marketplace = json.loads(marketplace_path.read_text())
    mp_skills = set()
    for plugin in marketplace.get("plugins", []):
        for s in plugin.get("skills", []):
            mp_skills.add(Path(s).name)
    settings_skills = set()
    for name, info in settings.get("skills", {}).items():
        settings_skills.add(Path(info["path"]).parent.name)
    missing = settings_skills - mp_skills
    if missing:
        errors.append(f"marketplace.json missing skills: {missing}")

if errors:
    print(f"Pre-commit check found {len(errors)} issue(s):")
    for e in errors:
        print(f"  - {e}")
    sys.exit(1)
else:
    print("Pre-commit check passed.")
    sys.exit(0)
```

- [ ] **Step 2: Document in CLAUDE.md**

Add to the end of CLAUDE.md:

```markdown
## Pre-commit Validation

Run before committing to catch common issues:
```bash
uv run scripts/pre-commit-check.py
```
Checks: SKILL.md frontmatter validity, settings.json → SKILL.md path consistency, YAML config parsing, step numbering gaps, marketplace.json completeness.
```

- [ ] **Step 3: Verify it passes on current codebase**

```bash
uv run scripts/pre-commit-check.py
```
Expected: "Pre-commit check passed." (fix any issues found first)

- [ ] **Step 4: Commit**

```bash
git add scripts/pre-commit-check.py CLAUDE.md && git commit -m "feat: add pre-commit validation script for skill files and config"
```

---

## Plan B: Experiment Pipeline

### Task 5: Token budget estimator

**Files:**
- Create: `tools/budget_estimator.py`
- Modify: `CLAUDE.md` (add to tool docs)

- [ ] **Step 1: Create budget_estimator.py**

```python
"""Estimate token usage and cost for an AI Scientist pipeline run.

Usage:
    uv run python3 tools/budget_estimator.py --config templates/bfts_config.yaml
    uv run python3 tools/budget_estimator.py --config config.yaml --idea idea.json
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# Rough token estimates per operation (based on observed usage)
TOKENS_PER_IDEA_REFLECTION = 8_000
TOKENS_PER_LIT_SEARCH = 3_000
TOKENS_PER_EXPERIMENT_STEP = 12_000
TOKENS_PER_MULTI_SEED_RUN = 2_000
TOKENS_PER_STAGE_TRANSITION = 5_000
TOKENS_PER_CITE_ROUND = 6_000
TOKENS_PER_WRITEUP_REFLECTION = 10_000
TOKENS_PER_REVIEW = 15_000
TOKENS_PER_CODEX_REVIEW = 20_000
TOKENS_PER_SCIENTIFIC_REVIEW = 10_000

# Cost per million tokens (approximate)
CLAUDE_COST_PER_M_INPUT = 3.0    # $/M input tokens
CLAUDE_COST_PER_M_OUTPUT = 15.0  # $/M output tokens
CODEX_COST_PER_M = 2.0           # $/M tokens (approximate)


def estimate(config: dict, num_ideas: int = 3) -> dict:
    stages = config.get("agent", {}).get("stages", {})
    s1 = stages.get("stage1_max_iters", 20)
    s2 = stages.get("stage2_max_iters", 12)
    s3 = stages.get("stage3_max_iters", 12)
    s4 = stages.get("stage4_max_iters", 18)
    total_iters = s1 + s2 + s3 + s4
    num_workers = config.get("agent", {}).get("num_workers", 2)
    num_reflections = 5
    cite_rounds = config.get("num_cite_rounds", 5)
    writeup_reflections = config.get("num_writeup_reflections", 3)

    codex_enabled = str(config.get("codex", {}).get("enabled", "auto")).lower() != "false"
    sci_enabled = str(config.get("scientific_skills", {}).get("enabled", "auto")).lower() != "false"

    ideation = num_ideas * (
        TOKENS_PER_IDEA_REFLECTION * num_reflections +
        TOKENS_PER_LIT_SEARCH * 2
    )
    experiments = total_iters * TOKENS_PER_EXPERIMENT_STEP
    multi_seed = 4 * 3 * TOKENS_PER_MULTI_SEED_RUN  # 4 stages * 3 seeds
    transitions = 3 * TOKENS_PER_STAGE_TRANSITION  # 3 transitions
    writeup = cite_rounds * TOKENS_PER_CITE_ROUND + writeup_reflections * TOKENS_PER_WRITEUP_REFLECTION
    review = TOKENS_PER_REVIEW

    claude_total = ideation + experiments + multi_seed + transitions + writeup + review

    codex_total = 0
    if codex_enabled:
        codex_total = (
            3 * TOKENS_PER_CODEX_REVIEW +  # 3 stage-gate reviews
            TOKENS_PER_CODEX_REVIEW         # panel paper review
        )

    if sci_enabled:
        claude_total += (
            num_ideas * TOKENS_PER_LIT_SEARCH * 3 +  # extra lit search per idea
            TOKENS_PER_SCIENTIFIC_REVIEW               # evidence assessment
        )

    return {
        "ideation": ideation,
        "experiments": experiments,
        "multi_seed": multi_seed,
        "transitions": transitions,
        "writeup": writeup,
        "review": review,
        "claude_total": claude_total,
        "codex_total": codex_total,
        "codex_enabled": codex_enabled,
        "scientific_skills_enabled": sci_enabled,
    }


def format_tokens(n: int) -> str:
    if n >= 1_000_000:
        return f"{n / 1_000_000:.1f}M"
    return f"{n / 1_000:.0f}K"


def main():
    parser = argparse.ArgumentParser(description="Estimate token usage for AI Scientist pipeline")
    parser.add_argument("--config", type=str, default="templates/bfts_config.yaml")
    parser.add_argument("--ideas", type=int, default=3, help="Number of ideas to generate")
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    args = parser.parse_args()

    import yaml
    with open(args.config) as f:
        config = yaml.safe_load(f)

    est = estimate(config, args.ideas)

    if args.json:
        print(json.dumps(est, indent=2))
        return

    print()
    print("Estimated token usage:")
    print(f"  Ideation ({args.ideas} ideas, 5 reflections):  {format_tokens(est['ideation']):>8}")
    print(f"  Experiments (4 stages):                {format_tokens(est['experiments']):>8}")
    print(f"  Multi-seed validation:                 {format_tokens(est['multi_seed']):>8}")
    print(f"  Stage transitions:                     {format_tokens(est['transitions']):>8}")
    print(f"  Writeup (citations + reflections):     {format_tokens(est['writeup']):>8}")
    print(f"  Review:                                {format_tokens(est['review']):>8}")
    print(f"  {'─' * 48}")
    print(f"  Total Claude:  {format_tokens(est['claude_total']):>8}")
    if est["codex_enabled"]:
        print(f"  Total Codex:   {format_tokens(est['codex_total']):>8}")
    print()

    # Cost estimate
    claude_cost = est["claude_total"] / 1_000_000 * (CLAUDE_COST_PER_M_INPUT + CLAUDE_COST_PER_M_OUTPUT) / 2
    codex_cost = est["codex_total"] / 1_000_000 * CODEX_COST_PER_M
    print(f"  Estimated cost: ~${claude_cost:.2f} (Claude)", end="")
    if est["codex_enabled"]:
        print(f" + ~${codex_cost:.2f} (Codex)", end="")
    print()
    print()


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Add to CLAUDE.md tool docs**

```
uv run python3 tools/budget_estimator.py --config FILE  # Estimate token usage and cost
```

- [ ] **Step 3: Verify**

```bash
uv run python3 tools/budget_estimator.py --config templates/bfts_config.yaml
```

- [ ] **Step 4: Commit**

```bash
git add tools/budget_estimator.py CLAUDE.md && git commit -m "feat: add token budget estimator for pipeline cost visibility"
```

---

### Task 6: Structured experiment logs

**Files:**
- Modify: `tools/state_manager.py` (add structured log to add-node)
- Modify: `skills/experiment-step/SKILL.md` (save structured log)

- [ ] **Step 1: Add structured log writing to state_manager.py**

Add a function after `save_best_solution()`:

```python
def save_structured_log(exp_dir: str, stage: str, node: dict) -> str:
    """Save a structured JSON log for a single experiment node."""
    log_dir = Path(exp_dir) / "logs" / "structured"
    log_dir.mkdir(parents=True, exist_ok=True)
    log_file = log_dir / f"{stage}_step{node.get('step', 0)}_{node['id'][:8]}.json"

    log_entry = {
        "node_id": node["id"],
        "stage": stage,
        "step": node.get("step", 0),
        "timestamp": node.get("created_at", ""),
        "parent_id": node.get("parent_id"),
        "is_buggy": node.get("is_buggy", False),
        "exec_time": node.get("exec_time", 0),
        "metric": node.get("metric"),
        "datasets": node.get("datasets_successfully_tested", []),
        "error": {
            "type": node.get("exc_type", ""),
            "message": node.get("exc_info", ""),
        } if node.get("is_buggy") else None,
        "plan": node.get("plan", ""),
        "plots": node.get("plot_paths", []),
    }

    with open(log_file, "w") as f:
        json.dump(log_entry, f, indent=2)
    return str(log_file)
```

- [ ] **Step 2: Call it from add-node CLI handler**

In the add-node CLI handler, after `save_journal()`, add:
```python
log_path = save_structured_log(args.exp_dir, args.stage, node)
```

- [ ] **Step 3: Update experiment-step to note structured logs**

Add to the "Report Results" section of experiment-step/SKILL.md:
```markdown
Structured logs are automatically saved to `<exp_dir>/logs/structured/` for each node.
```

- [ ] **Step 4: Commit**

```bash
git add tools/state_manager.py skills/experiment-step/SKILL.md && git commit -m "feat: save structured JSON logs per experiment node"
```

---

### Task 7: Experiment result caching/deduplication

**Files:**
- Modify: `tools/state_manager.py` (add content hash check)
- Modify: `skills/experiment-step/SKILL.md` (check hash before executing)

- [ ] **Step 1: Add code hash function to state_manager.py**

```python
import hashlib

def get_code_hash(code: str) -> str:
    """Return SHA-256 hash of code content (whitespace-normalized)."""
    normalized = "\n".join(line.rstrip() for line in code.strip().splitlines())
    return hashlib.sha256(normalized.encode()).hexdigest()[:16]


def find_duplicate_node(journal: dict, code: str) -> Optional[dict]:
    """Check if identical code was already executed in this stage."""
    target_hash = get_code_hash(code)
    for node in journal["nodes"]:
        if get_code_hash(node.get("code", "")) == target_hash:
            return node
    return None
```

- [ ] **Step 2: Add dedup-check CLI subcommand**

```python
# In the CLI argument parser, add:
sub = subparsers.add_parser("dedup-check", help="Check if code already executed")
sub.add_argument("exp_dir")
sub.add_argument("stage")
sub.add_argument("--code", required=True, help="Path to code file")
```

Handler:
```python
elif args.command == "dedup-check":
    journal = load_journal(args.exp_dir, args.stage)
    code = Path(args.code).read_text()
    dup = find_duplicate_node(journal, code)
    if dup:
        print(json.dumps({"duplicate": True, "node_id": dup["id"], "step": dup.get("step"), "metric": dup.get("metric")}))
    else:
        print(json.dumps({"duplicate": False}))
```

- [ ] **Step 3: Update experiment-step to check before executing**

In experiment-step/SKILL.md, before the "Write and Execute Code" section, add:

```markdown
**Before executing**, check if identical code was already run in this stage:
```bash
uv run python3 tools/state_manager.py dedup-check <exp_dir> <stage> --code <exp_dir>/workspace/runfile.py
```
If `"duplicate": true`, skip execution and reuse the existing node's metrics. Report: "Skipped — identical code already executed (node <id>, metric: <value>)".
```

- [ ] **Step 4: Commit**

```bash
git add tools/state_manager.py skills/experiment-step/SKILL.md && git commit -m "feat: content-hash deduplication for experiment code"
```

---

### Task 8: Split experiment-step into generate + execute

**Files:**
- Create: `skills/experiment-generate/SKILL.md`
- Create: `skills/experiment-execute/SKILL.md`
- Modify: `skills/experiment-step/SKILL.md` (delegate to sub-skills)
- Modify: `.claude/settings.json` (register new skills)
- Modify: `.claude-plugin/marketplace.json` (export new skills)

- [ ] **Step 1: Create experiment-generate skill**

Create `skills/experiment-generate/SKILL.md`:

```markdown
---
name: experiment-generate
description: Generate experiment code for a BFTS iteration. Produces Python code without executing it — pairs with experiment-execute for the full iteration.
---


# Experiment Code Generation

You generate Python experiment code for a single BFTS iteration. This skill produces code only — it does NOT execute it. Use `/ai-scientist:experiment-execute` to run the generated code.

## Arguments

Same as experiment-step: `--exp-dir`, `--stage`, `--parent-id`, `--action`, `--task-desc`, `--stage-goals`

## Procedure

### 1. Load Context

```bash
uv run python3 tools/state_manager.py journal-summary <exp_dir> <stage>
```

If parent node ID provided:
```bash
uv run python3 tools/state_manager.py node-info <exp_dir> <stage> <parent_id> --show-code
```

### 2. Detect Device

```bash
uv run python3 tools/device_utils.py --preamble
```

### 3. Generate Code

Based on action type (draft/debug/improve), generate the complete Python experiment script. Follow all code requirements from experiment-step (device preamble, metric printing, figures/, seeds, <60 min).

### 4. Write Code (do NOT execute)

```bash
cat > <exp_dir>/workspace/runfile.py << 'PYTHON_EOF'
<generated code>
PYTHON_EOF
mkdir -p <exp_dir>/workspace/figures
```

### 5. Check for Duplicates

```bash
uv run python3 tools/state_manager.py dedup-check <exp_dir> <stage> --code <exp_dir>/workspace/runfile.py
```

If duplicate found, report it and skip — no need to execute.

### 6. Report

Print the generated code path and a brief description of the approach.
```

- [ ] **Step 2: Create experiment-execute skill**

Create `skills/experiment-execute/SKILL.md`:

```markdown
---
name: experiment-execute
description: Execute previously generated experiment code, parse metrics, analyze plots, and record the node. Pairs with experiment-generate.
---


# Experiment Execution

You execute a previously generated experiment script, parse its output, and record the result as a BFTS node.

## Arguments

- `--exp-dir <path>`: Experiment directory
- `--stage <name>`: Current stage
- `--parent-id <id>`: Parent node ID (optional)
- `--plan <text>`: Brief plan description for this node

## Procedure

### 1. Execute Code

```bash
cd <exp_dir>/workspace && timeout 3600 uv run python3 runfile.py 2>&1 | tee <exp_dir>/logs/step_<N>_output.txt
```

Determine step number from journal:
```bash
uv run python3 tools/state_manager.py journal-summary <exp_dir> <stage>
```

### 2. Parse Metrics

```bash
uv run python3 tools/metric_parser.py <exp_dir>/logs/step_<N>_output.txt --json
```

### 3. Analyze Plots

If plots exist in `<exp_dir>/workspace/figures/`, view each PNG with the Read tool.

### 4. Determine Bug Status

Buggy if: exception raised, no valid metrics, timeout, NaN/Inf in metrics.

### 5. Save Node

```bash
uv run python3 tools/state_manager.py add-node <exp_dir> <stage> \
    --plan "<plan>" \
    --code <exp_dir>/workspace/runfile.py \
    --output-log <exp_dir>/logs/step_<N>_output.txt \
    --exec-time <seconds> \
    --metric '<metric_json>' \
    --datasets <dataset1> <dataset2> \
    --plots <plot_paths> \
    [--parent-id <parent_id>] \
    [--buggy] \
    [--analysis "<analysis>"]
```

### 6. Report

Node ID, action type, metrics, bug status, recommendation for next step.
```

- [ ] **Step 3: Update experiment-step to delegate**

Add to the top of experiment-step/SKILL.md, after the description:

```markdown
## Note

This skill can optionally delegate to two sub-skills for better failure recovery:
- `/ai-scientist:experiment-generate` — produces code (saved even if execution fails)
- `/ai-scientist:experiment-execute` — runs code, parses metrics, records node

When the experiment skill launches this as a subagent, the monolithic flow below is used. The split skills are available for retry scenarios where only execution needs to re-run.
```

- [ ] **Step 4: Register new skills**

In `.claude/settings.json`, add:
```json
"ai-scientist:experiment-generate": {
    "type": "prompt",
    "path": "skills/experiment-generate/SKILL.md"
},
"ai-scientist:experiment-execute": {
    "type": "prompt",
    "path": "skills/experiment-execute/SKILL.md"
},
```

In `.claude-plugin/marketplace.json`, add to the skills array:
```json
"./skills/experiment-generate",
"./skills/experiment-execute",
```

- [ ] **Step 5: Commit**

```bash
git add skills/experiment-generate/ skills/experiment-execute/ skills/experiment-step/SKILL.md .claude/settings.json .claude-plugin/marketplace.json && git commit -m "feat: split experiment-step into generate + execute sub-skills"
```

---

### Task 9: Parallel literature search in ideation

**Files:**
- Modify: `skills/ideation/SKILL.md` (restructure enhanced lit search)

- [ ] **Step 1: Update the Enhanced Literature Search section**

Replace the sequential search instructions with parallel agent dispatch:

```markdown
When enabled, run all search backends in parallel using Agent subagents:

```
Agent 1: uv run python3 tools/search.py "<topic keywords>" --limit 10 --json
Agent 2: /research-lookup "<topic keywords and hypothesis>"
Agent 3: /paper-lookup "<specific query>" (if available)
```

Wait for all agents to complete. Merge results:
- Deduplicate papers by title similarity
- Prioritize by citation count
- Use the combined evidence for novelty assessment

If `/paper-lookup` or `/database-lookup` are not available, those agents simply return empty results — the parallel dispatch handles missing skills gracefully.
```

- [ ] **Step 2: Commit**

```bash
git add skills/ideation/SKILL.md && git commit -m "feat: parallel literature search in ideation using Agent subagents"
```

---

## Plan C: Review Feedback Loop

### Task 10: Review feedback loop with configurable passes

**Files:**
- Modify: `tools/config.py` (add RevisionConfig dataclass)
- Modify: `templates/bfts_config.yaml` (add revision section)
- Modify: `skills/ai-scientist/SKILL.md` (add revision phase)
- Modify: `CLAUDE.md` (document new config)

- [ ] **Step 1: Add RevisionConfig dataclass**

In tools/config.py, after ScientificSkillsConfig:

```python
@dataclass
class RevisionConfig:
    enabled: bool = False
    score_threshold: int = 5       # re-run if Overall < this
    max_passes: int = 2            # max revision cycles
    prompt_before_revision: bool = True  # ask user before each revision
```

Add to Config class:
```python
    # Revision loop
    revision: RevisionConfig = field(default_factory=RevisionConfig)
```

- [ ] **Step 2: Add revision section to bfts_config.yaml**

```yaml
# ── Revision loop (optional — re-review after poor scores) ─────────────────
revision:
  enabled: false               # opt-in: write → review → revise → re-review
  score_threshold: 5           # re-run if Overall score < this (1-10 scale)
  max_passes: 2                # max revision cycles (prevent infinite loops)
  prompt_before_revision: true # ask user before each revision pass
```

- [ ] **Step 3: Add --revision-passes argument to orchestrator**

In skills/ai-scientist/SKILL.md Arguments section:
```markdown
- `--revision-passes <N>`: Number of review-revise cycles (overrides config, 0 = no revision)
```

- [ ] **Step 4: Add revision phase to orchestrator**

After Phase 6 (Paper Review) and before Phase 7 (Summary Report), add:

```markdown
### Phase 6.5: Revision Loop (Optional)

**Skip if** `revision.enabled` is `false` in config AND `--revision-passes` is not set.

If `--revision-passes <N>` is provided, use that as max passes (overrides config). Otherwise use `revision.max_passes` from config.

For each revision pass (up to max_passes):

1. **Check score**: Read the review from `<exp_dir>/review.json`. Extract the `Overall` score (1-10).
   - If `Overall >= revision.score_threshold`: print "Review score <score>/10 meets threshold (<threshold>). No revision needed." and **break the loop**.

2. **Prompt user** (if `revision.prompt_before_revision` is `true`):
   Ask the user:
   > "Review score is <score>/10 (threshold: <threshold>). Revision pass <N>/<max>. Options:"
   > 1. "Revise and re-review (recommended)"
   > 2. "Accept current paper and stop"

   If user chooses to stop, break the loop.

3. **Extract actionable feedback**: From the review JSON, collect:
   - All items in `Weaknesses` array
   - All items in `Questions` array
   - If Codex review exists (`codex_review.md`), extract its weaknesses too
   - If evidence assessment exists (`evidence_assessment.md`), extract concerns

4. **Map feedback to phases**: Categorize each weakness:
   - "missing baselines", "insufficient experiments", "more datasets" → re-run relevant experiment stage
   - "unclear writing", "poor organization", "grammar" → re-run writeup
   - "missing citations", "uncited claims" → re-run citation gathering in writeup
   - "figure quality", "unclear plots" → re-run plot aggregation
   - Everything else → re-run writeup (default)

5. **Re-run affected phases**:
   - If experiments need re-running: invoke `/ai-scientist:experiment --exp-dir <exp_dir> --start-stage <relevant_stage>`
   - If plots need re-running: invoke `/ai-scientist:plot --exp-dir <exp_dir>`
   - If writeup needs re-running: invoke `/ai-scientist:writeup --exp-dir <exp_dir> --type <type>` with the review feedback injected into the task context
   - Always re-run writeup after any experiment/plot changes

6. **Re-review**: invoke `/ai-scientist:review --pdf <exp_dir>/paper.pdf --exp-dir <exp_dir>`
   - Save as `review_pass<N>.json` to preserve history
   - Copy to `review.json` for next iteration

7. **Report revision**: "Revision pass <N> complete. New score: <new_score>/10 (was: <old_score>/10)"

After all passes complete (or threshold met), proceed to Phase 7.
```

- [ ] **Step 5: Update Phase 7 summary**

Add to the summary report:
```
  Revisions:   <N> pass(es) (score: <initial> → <final>)
```

- [ ] **Step 6: Update CLAUDE.md with revision config**

Add to the config documentation:
```yaml
revision:
  enabled: false
  score_threshold: 5
  max_passes: 2
  prompt_before_revision: true
```

- [ ] **Step 7: Commit**

```bash
git add tools/config.py templates/bfts_config.yaml skills/ai-scientist/SKILL.md CLAUDE.md && git commit -m "feat: add review feedback loop with configurable revision passes and user prompt"
```

---

## Verification Checklist

After all tasks complete:

- [ ] `grep -rn "python3" skills/ CLAUDE.md README.md | grep -v "uv run python3" | grep -v "#"` — no bare python3 remains
- [ ] `uv run python3 tools/device_utils.py --preamble | grep SEED` — env var seed in preamble
- [ ] `grep "dry-run" skills/ai-scientist/SKILL.md` — dry-run mode documented
- [ ] `uv run scripts/pre-commit-check.py` — passes
- [ ] `uv run python3 tools/budget_estimator.py --config templates/bfts_config.yaml` — runs
- [ ] `grep "dedup-check" tools/state_manager.py` — dedup command exists
- [ ] `ls skills/experiment-generate/SKILL.md skills/experiment-execute/SKILL.md` — split skills exist
- [ ] `grep "revision" templates/bfts_config.yaml` — revision config exists
- [ ] `grep "Phase 6.5" skills/ai-scientist/SKILL.md` — revision loop in orchestrator
- [ ] `python3 -c "import json; d=json.load(open('.claude/settings.json')); print(len(d['skills']))"` — 12 skills (10 original + 2 new)
