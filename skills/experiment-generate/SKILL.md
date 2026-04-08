---
name: experiment-generate
description: Generate experiment code for a BFTS iteration. Produces Python code without executing it — pairs with experiment-execute for the full iteration.
---


# Experiment Code Generation

You generate Python experiment code for a single BFTS iteration. This skill produces code only — it does NOT execute it. Use `/ai-scientist:experiment-execute` to run the generated code.

## Arguments

Same as experiment-step: `--exp-dir`, `--stage`, `--parent-id`, `--action`, `--task-desc`, `--stage-goals`

## Procedure

### 0. Locate Plugin Root

```bash
export AISCIENTIST_ROOT=$(claude plugin list --json 2>/dev/null | python3 -c "import json,sys;print(next((p['installPath'] for p in json.load(sys.stdin) if 'ai-sci' in p['id']),''))" 2>/dev/null)
[ -z "$AISCIENTIST_ROOT" ] && echo "ERROR: ai-scientist plugin not found"
echo "Plugin root: $AISCIENTIST_ROOT"
```

### 1. Load Context

```bash
uv run python3 "$AISCIENTIST_ROOT/tools/state_manager.py" journal-summary <exp_dir> <stage>
```

If parent node ID provided:
```bash
uv run python3 "$AISCIENTIST_ROOT/tools/state_manager.py" node-info <exp_dir> <stage> <parent_id> --show-code
```

### 2. Detect Device

```bash
uv run python3 "$AISCIENTIST_ROOT/tools/device_utils.py" --preamble
```

### 3. Generate Code

Based on action type (draft/debug/improve), generate the complete Python experiment script. Follow all code requirements from experiment-step (device preamble with SEED env var, metric printing as `metric_name: value`, figures/ directory, <60 min execution).

### 4. Write Code (do NOT execute)

```bash
cat > <exp_dir>/workspace/runfile.py << 'PYTHON_EOF'
<generated code>
PYTHON_EOF
mkdir -p <exp_dir>/workspace/figures
```

### 5. Check for Duplicates

```bash
uv run python3 "$AISCIENTIST_ROOT/tools/state_manager.py" dedup-check <exp_dir> <stage> --code <exp_dir>/workspace/runfile.py
```

If duplicate found, report it and skip — no need to execute.

### 6. Report

Print the generated code path and a brief description of the approach. Do NOT execute the code.
