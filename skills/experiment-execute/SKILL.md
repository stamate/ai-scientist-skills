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

### 0. Locate Plugin Root

```bash
export AISCIENTIST_ROOT=$(claude plugin list --json 2>/dev/null | python3 -c "import json,sys;print(next((p['installPath'] for p in json.load(sys.stdin) if 'ai-sci' in p['id']),''))" 2>/dev/null)
[ -z "$AISCIENTIST_ROOT" ] && echo "ERROR: ai-scientist plugin not found"
echo "Plugin root: $AISCIENTIST_ROOT"
```

### 1. Execute Code

Determine step number from journal:
```bash
uv run python3 "$AISCIENTIST_ROOT/tools/state_manager.py" journal-summary <exp_dir> <stage>
```

Run the previously generated code:
```bash
cd <exp_dir>/workspace && timeout 3600 uv run python3 runfile.py 2>&1 | tee <exp_dir>/logs/step_<N>_output.txt
```

### 2. Parse Metrics

```bash
uv run python3 "$AISCIENTIST_ROOT/tools/metric_parser.py" <exp_dir>/logs/step_<N>_output.txt --json
```

### 3. Analyze Plots

If plots exist in `<exp_dir>/workspace/figures/`, view each PNG with the Read tool. Assess convergence, overfitting, dataset consistency.

### 4. Determine Bug Status

Buggy if: exception raised, no valid metrics, timeout, NaN/Inf in metrics.

### 5. Save Node

```bash
uv run python3 "$AISCIENTIST_ROOT/tools/state_manager.py" add-node <exp_dir> <stage> \
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

Node ID, bug status, metrics, recommendation for next step.
