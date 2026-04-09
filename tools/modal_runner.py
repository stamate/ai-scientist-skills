"""Run experiment code on Modal.com cloud GPUs."""

from __future__ import annotations

import argparse
import json
import sys
import tempfile
from pathlib import Path


def run_on_modal(code_path: str, gpu: str = "T4", timeout: int = 3600) -> dict:
    """Execute a Python script on Modal with the specified GPU.

    Returns dict with stdout, stderr, exit_code.
    """
    try:
        import modal
    except ImportError:
        print("ERROR: modal package not installed. Run: uv pip install modal", file=sys.stderr)
        return {"exit_code": 1, "stdout": "", "stderr": "modal not installed"}

    code = Path(code_path).read_text()
    requirements_text = ""
    req_path = Path(code_path).parent / "requirements.txt"
    if req_path.exists():
        requirements_text = req_path.read_text()

    # Parse imports from code to install dependencies
    imports = _extract_imports(code)

    app = modal.App("ai-scientist-experiment")

    # Build image with dependencies
    image = modal.Image.debian_slim(python_version="3.12")
    # Always include core scientific packages
    image = image.pip_install(
        "torch", "numpy", "matplotlib", "seaborn",
        "datasets", "transformers", "scikit-learn",
        "pandas", "tqdm", "pyyaml",
    )
    # Add any extra packages from requirements.txt
    if requirements_text:
        for line in requirements_text.strip().splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                image = image.pip_install(line)

    @app.function(
        image=image,
        gpu=gpu,
        timeout=timeout,
        # Upload the workspace directory for figures, data, etc.
    )
    def execute_experiment(script_code: str) -> dict:
        """Run the experiment script and capture output."""
        import subprocess
        import tempfile as tf
        import os

        # Write code to temp file
        with tf.NamedTemporaryFile(mode="w", suffix=".py", delete=False, dir="/tmp") as f:
            f.write(script_code)
            script_path = f.name

        # Create figures directory
        os.makedirs("figures", exist_ok=True)

        # Run the script
        result = subprocess.run(
            ["python3", script_path],
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd="/tmp",
        )

        return {
            "exit_code": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr,
        }

    # Run on Modal
    with app.run():
        result = execute_experiment.remote(code)

    return result


def _extract_imports(code: str) -> list[str]:
    """Extract import names from Python code."""
    imports = set()
    for line in code.splitlines():
        line = line.strip()
        if line.startswith("import "):
            mod = line.split()[1].split(".")[0].split(",")[0]
            imports.add(mod)
        elif line.startswith("from "):
            mod = line.split()[1].split(".")[0]
            imports.add(mod)
    return list(imports)


def main():
    parser = argparse.ArgumentParser(description="Run experiment on Modal.com")
    parser.add_argument("code_path", help="Path to Python script to execute")
    parser.add_argument("--gpu", default="T4", help="GPU type: T4, A100, H100, L4 (default: T4)")
    parser.add_argument("--timeout", type=int, default=3600, help="Timeout in seconds")
    parser.add_argument("--output-log", default=None, help="Write stdout to this file")
    args = parser.parse_args()

    result = run_on_modal(args.code_path, gpu=args.gpu, timeout=args.timeout)

    # Print stdout (this is what metrics parser reads)
    if result["stdout"]:
        print(result["stdout"])

    # Print stderr to stderr
    if result["stderr"]:
        print(result["stderr"], file=sys.stderr)

    # Save to log file if requested
    if args.output_log:
        Path(args.output_log).parent.mkdir(parents=True, exist_ok=True)
        with open(args.output_log, "w") as f:
            f.write(result["stdout"])
            if result["stderr"]:
                f.write("\n--- STDERR ---\n")
                f.write(result["stderr"])

    sys.exit(result["exit_code"])


if __name__ == "__main__":
    main()
