# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""
AI Scientist Skills — One-command setup. Run directly from GitHub:

  uv run https://raw.githubusercontent.com/stamate/ai-scientist-skills/main/scripts/setup.py

Modes:
  (default)  Install plugins globally (--scope user)
  --project  Install plugins into current project (--scope project)
  --local    Clone repo here + install plugins at project scope + Python deps
  --check    Verify installation status
  --deps     Python dependencies only (requires local repo)

Plugin scopes (from `claude plugin install --scope`):
  user     ~/.claude/plugins/ — available in all projects (default)
  project  .claude/plugins/   — available only in this project
  local    .claude/plugins/   — available only on this machine for this project
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

REPO = "stamate/ai-scientist-skills"
REPO_URL = f"https://github.com/{REPO}.git"

GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
BOLD = "\033[1m"
RESET = "\033[0m"
CHECK = f"{GREEN}\u2713{RESET}"
CROSS = f"{RED}\u2717{RESET}"
WARN = f"{YELLOW}!{RESET}"


def run(cmd: list[str], **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, timeout=300, **kwargs)


def run_live(cmd: list[str], **kwargs) -> int:
    return subprocess.call(cmd, timeout=300, **kwargs)


def step(msg: str) -> None:
    print(f"\n{BOLD}{msg}{RESET}")


def ok(msg: str) -> None:
    print(f"  {CHECK} {msg}")


def fail(msg: str) -> None:
    print(f"  {CROSS} {msg}")


def warn(msg: str) -> None:
    print(f"  {WARN} {msg}")


# ── Clone ──────────────────────────────────────────────────────────────────────


def clone_repo(target: Path) -> bool:
    step("Cloning ai-scientist-skills")
    if (target / ".git").exists():
        ok(f"Already cloned at {target}")
        return True

    git = shutil.which("git")
    if not git:
        fail("git not found")
        return False

    result = run([git, "clone", REPO_URL, str(target)])
    if result.returncode == 0:
        ok(f"Cloned to {target}")
        return True

    fail(f"Clone failed: {result.stderr[:200]}")
    return False


# ── Python deps ────────────────────────────────────────────────────────────────


def install_python_deps(project_root: Path) -> bool:
    step("Python dependencies")

    uv = shutil.which("uv")
    if uv and (project_root / "pyproject.toml").exists():
        # Try uv sync first (creates .venv/ + installs from pyproject.toml)
        rc = run_live([uv, "sync", "--project", str(project_root)])
        if rc == 0:
            ok(f"Installed via uv sync")
            return True
        # Fallback: uv run auto-creates .venv on first use from pyproject.toml
        # Pre-install deps so first uv run is fast
        rc = run_live([uv, "pip", "install", "--system", "-r",
                       str(project_root / "requirements.txt")])
        if rc == 0:
            ok("Installed via uv pip")
            return True

    req_file = project_root / "requirements.txt"
    if not req_file.exists():
        warn("requirements.txt not found — skipping Python deps")
        return False

    pip = shutil.which("pip3") or shutil.which("pip")
    if pip:
        result = run([pip, "install", "-r", str(req_file)])
        if result.returncode == 0:
            ok("Installed via pip")
            return True
        warn(f"pip failed: {result.stderr[:200]}")
        return False

    fail("Neither uv nor pip found")
    return False


# ── Claude plugins ─────────────────────────────────────────────────────────────


def add_marketplace(repo: str, scope: str = "user") -> bool:
    """Register a GitHub repo as a Claude Code marketplace."""
    claude = shutil.which("claude")
    if not claude:
        return False
    result = run([claude, "plugin", "marketplace", "add", repo, "--scope", scope])
    return result.returncode == 0 or "already" in (result.stdout + result.stderr).lower()


def install_claude_plugin(marketplace: str, plugin: str, repo: str, scope: str = "user") -> bool:
    claude = shutil.which("claude")
    if not claude:
        fail(f"Claude Code CLI not found — cannot install {plugin}")
        return False

    # Step 1: Add the marketplace (repo) if not already registered
    add_marketplace(repo, scope)

    # Step 2: Install the plugin from that marketplace
    plugin_ref = f"{plugin}@{marketplace}"
    result = run([claude, "plugin", "install", plugin_ref, "--scope", scope])
    out = result.stdout + result.stderr
    if result.returncode == 0 or "already" in out.lower():
        ok(f"{plugin_ref} (scope: {scope})")
        return True

    fail(f"{plugin_ref} — {out.strip()[:200]}")
    return False


def install_all_plugins(scope: str = "user") -> bool:
    # (marketplace_name, plugin_name, github_repo)
    plugins = [
        ("ai-scientist-skills", "ai-scientist", "stamate/ai-scientist-skills"),
        ("stamate-codex", "codex", "stamate/codex-plugin-cc"),
        ("claude-scientific-skills", "scientific-skills", "stamate/claude-scientific-skills"),
    ]
    step(f"Claude Code plugins ({len(plugins)}, scope: {scope})")
    all_ok = True
    for marketplace, plugin, repo in plugins:
        if not install_claude_plugin(marketplace, plugin, repo, scope):
            all_ok = False
    return all_ok


# ── Find plugin requirements ──────────────────────────────────────────────────


def find_plugin_requirements() -> Path | None:
    """Find requirements.txt in the ai-scientist-skills plugin cache."""
    for search_root in [
        Path(".claude") / "plugins",
        Path.home() / ".claude" / "plugins" / "cache",
        Path.home() / ".claude" / "plugins",
    ]:
        if not search_root.exists():
            continue
        try:
            result = run(["find", str(search_root), "-maxdepth", "8",
                          "-name", "requirements.txt", "-path", "*ai-scientist*"])
            if result.stdout.strip():
                p = Path(result.stdout.strip().splitlines()[0])
                if p.exists():
                    ok(f"Found {p}")
                    return p
        except Exception:
            pass
    return None


# ── Codex CLI ──────────────────────────────────────────────────────────────────


def install_codex_cli() -> bool:
    step("Codex CLI")
    if shutil.which("codex"):
        ok("Already installed")
        return True

    npm = shutil.which("npm")
    if not npm:
        warn("npm not found — install Node.js to get Codex CLI")
        return False

    result = run([npm, "install", "-g", "@openai/codex"])
    if result.returncode == 0:
        ok("Installed")
        warn("Run 'codex login' to authenticate")
        return True

    warn(f"npm install failed: {result.stderr[:200]}")
    return False


# ── Verify ─────────────────────────────────────────────────────────────────────


def verify(project_root: Path | None) -> None:
    step("Verification")
    if project_root and (project_root / "tools" / "verify_setup.py").exists():
        run_live([sys.executable, str(project_root / "tools" / "verify_setup.py")])
    else:
        # Quick check without local repo
        for name, cmd in [
            ("Claude Code", ["claude", "--version"]),
            ("Codex CLI", ["codex", "--version"]),
        ]:
            if shutil.which(cmd[0]):
                ok(name)
            else:
                warn(f"{name} not found")


# ── Main ───────────────────────────────────────────────────────────────────────


def detect_project_root() -> Path | None:
    """Find project root if we're inside the repo."""
    here = Path.cwd()
    for p in [here, *here.parents]:
        if (p / "pyproject.toml").exists() and (p / "skills").exists():
            return p
    # Also check relative to this script (when run locally)
    script_parent = Path(__file__).resolve().parent.parent
    if (script_parent / "pyproject.toml").exists():
        return script_parent
    return None


def main():
    import argparse

    url = f"https://raw.githubusercontent.com/{REPO}/main/scripts/setup.py"
    parser = argparse.ArgumentParser(
        description="AI Scientist Skills — one-command setup",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=f"""
Examples:
  # Install into current project (recommended):
  cd my-research-project && uv run {url} --project

  # Install plugins globally (available everywhere):
  uv run {url}

  # Clone repo for development:
  uv run {url} --local

  # Just check what's installed:
  uv run {url} --check
""",
    )
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--project", action="store_true",
        help="Install plugins at project scope in current directory + .venv + Python deps (no clone needed)",
    )
    mode.add_argument(
        "--local", action="store_true",
        help="Clone repo + project-scoped plugins + .venv + Python deps (for development)",
    )
    mode.add_argument("--check", action="store_true", help="Verify installation")
    args = parser.parse_args()

    print(f"\n{BOLD}=== AI Scientist Skills — Setup ==={RESET}")

    project_root = detect_project_root()

    if args.check:
        verify(project_root)
        return

    success = True

    if args.project:
        # Project setup: install plugins HERE (in the user's project dir) + .venv + deps
        # No clone — tools live in the plugin cache, discovered via AISCIENTIST_ROOT
        if not install_all_plugins("project"):
            success = False
        install_codex_cli()

        # Create .venv and install Python deps from plugin cache's requirements.txt
        step("Python dependencies")
        plugin_req = find_plugin_requirements()
        if plugin_req:
            uv = shutil.which("uv")
            if uv:
                venv_path = Path.cwd() / ".venv"
                if not venv_path.exists():
                    print(f"  Creating .venv/ in {Path.cwd()}")
                    run_live([uv, "venv", str(venv_path)])
                # Explicitly target the project's .venv, not uv's temp env
                pip_python = str(venv_path / "bin" / "python")
                rc = run_live([uv, "pip", "install",
                               "--python", pip_python,
                               "-r", str(plugin_req)])
                if rc == 0:
                    ok(f"Installed into {venv_path}/")
                else:
                    warn(f"Failed. Run: uv pip install --python {pip_python} -r {plugin_req}")
                    success = False
            else:
                warn("uv not found")
                success = False
        else:
            warn("Could not find requirements.txt in plugin cache")

        verify(project_root)

    elif args.local:
        # Dev setup: clone repo + project-scoped plugins + deps
        target = Path.cwd() / "ai-scientist-skills"
        if project_root:
            print(f"  Already in repo at {project_root}")
            target = project_root
        else:
            if not clone_repo(target):
                sys.exit(1)
        os.chdir(target)
        install_python_deps(target)
        if not install_all_plugins("project"):
            success = False
        install_codex_cli()
        verify(target)

    else:
        # Global: plugins only
        if not install_all_plugins("user"):
            success = False
        install_codex_cli()
        verify(project_root)

    if success:
        print(f"\n{BOLD}=== Done ==={RESET}")
    else:
        print(f"\n{BOLD}=== Done (with errors) ==={RESET}")

    if args.project:
        print(f"  Scope: project ({Path.cwd()})")
        print(f"\n  Quick start:")
        print(f"    claude '/ai-scientist --workshop examples/ideas/i_cant_believe_its_not_better.md'")
    elif args.local:
        root = project_root or target
        print(f"  Scope: project (cloned to {root})")
        print(f"\n  Quick start:")
        print(f"    cd {root}")
        print(f"    claude '/ai-scientist --workshop examples/ideas/i_cant_believe_its_not_better.md'")
    else:
        print(f"  Scope: global")
        print(f"\n  For project-scoped setup, run from your project dir:")
        print(f"    cd your-project && uv run {url} --project")
    print()

    if not success:
        sys.exit(1)


if __name__ == "__main__":
    main()
