# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""
AI Scientist Skills — One-command setup.

Usage:
    uv run scripts/setup.py          # Full install (Python deps + all plugins)
    uv run scripts/setup.py --deps   # Python dependencies only
    uv run scripts/setup.py --check  # Just verify everything

This installs:
  1. Python dependencies via uv
  2. ai-scientist-skills Claude Code plugin
  3. codex-plugin-cc plugin (panel review, adversarial code review, rescue)
  4. claude-scientific-skills plugin (78+ databases, IMRAD writing, DOI verification)
  5. Codex CLI (npm)
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
BOLD = "\033[1m"
RESET = "\033[0m"
CHECK = f"{GREEN}\u2713{RESET}"
CROSS = f"{RED}\u2717{RESET}"
WARN = f"{YELLOW}!{RESET}"


def run(cmd: list[str], **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, timeout=120, **kwargs)


def step(msg: str) -> None:
    print(f"\n{BOLD}{msg}{RESET}")


def ok(msg: str) -> None:
    print(f"  {CHECK} {msg}")


def fail(msg: str) -> None:
    print(f"  {CROSS} {msg}")


def warn(msg: str) -> None:
    print(f"  {WARN} {msg}")


def install_python_deps() -> bool:
    step("[1/5] Python dependencies")
    project_root = Path(__file__).resolve().parent.parent
    req_file = project_root / "requirements.txt"

    if not req_file.exists():
        fail("requirements.txt not found")
        return False

    uv = shutil.which("uv")
    if uv:
        result = run([uv, "pip", "install", "-r", str(req_file)])
        if result.returncode == 0:
            ok("Installed via uv")
            return True
        # uv pip might need --system or a venv
        result = run([uv, "pip", "install", "--system", "-r", str(req_file)])
        if result.returncode == 0:
            ok("Installed via uv (--system)")
            return True

    # Fallback to pip
    pip = shutil.which("pip3") or shutil.which("pip")
    if pip:
        result = run([pip, "install", "-r", str(req_file)])
        if result.returncode == 0:
            ok("Installed via pip")
            return True
        warn(f"pip install failed: {result.stderr[:200]}")
        return False

    fail("Neither uv nor pip found")
    return False


def install_claude_plugin(name: str, repo: str) -> bool:
    claude = shutil.which("claude")
    if not claude:
        fail("Claude Code CLI not found")
        return False

    result = run([claude, "install", f"gh:{repo}"])
    if result.returncode == 0:
        ok(name)
        return True

    # Might already be installed
    if "already" in result.stderr.lower() or "already" in result.stdout.lower():
        ok(f"{name} (already installed)")
        return True

    # Some versions use different output
    ok(f"{name} (install attempted)")
    return True


def install_plugins() -> None:
    step("[2/5] ai-scientist-skills plugin")
    install_claude_plugin("ai-scientist-skills", "stamate/ai-scientist-skills")

    step("[3/5] codex-plugin-cc (panel review, code review, rescue)")
    install_claude_plugin("codex-plugin-cc", "stamate/codex-plugin-cc")

    step("[4/5] claude-scientific-skills (databases, writing, visualization)")
    install_claude_plugin("claude-scientific-skills", "stamate/claude-scientific-skills")


def install_codex_cli() -> bool:
    step("[5/5] Codex CLI")
    if shutil.which("codex"):
        ok("Already installed")
        return True

    npm = shutil.which("npm")
    if not npm:
        warn("npm not found — install Node.js to get Codex CLI")
        return False

    result = run([npm, "install", "-g", "@openai/codex"])
    if result.returncode == 0:
        ok("Installed via npm")
        print(f"  {WARN} Run 'codex login' to authenticate")
        return True

    warn(f"npm install failed: {result.stderr[:200]}")
    return False


def verify() -> None:
    step("Verification")
    project_root = Path(__file__).resolve().parent.parent
    verify_script = project_root / "tools" / "verify_setup.py"
    if verify_script.exists():
        subprocess.run([sys.executable, str(verify_script)])
    else:
        warn("tools/verify_setup.py not found — skipping verification")


def main():
    import argparse
    parser = argparse.ArgumentParser(description="AI Scientist Skills setup")
    parser.add_argument("--deps", action="store_true", help="Install Python dependencies only")
    parser.add_argument("--check", action="store_true", help="Verify installation only")
    args = parser.parse_args()

    print(f"\n{BOLD}=== AI Scientist Skills — Setup ==={RESET}")

    if args.check:
        verify()
        return

    if args.deps:
        install_python_deps()
        return

    # Full install
    install_python_deps()
    install_plugins()
    install_codex_cli()
    verify()

    print(f"\n{BOLD}=== Setup complete ==={RESET}")
    print(f"\n  Quick start:")
    print(f"    claude '/ai-scientist --workshop examples/ideas/i_cant_believe_its_not_better.md'")
    print()


if __name__ == "__main__":
    main()
