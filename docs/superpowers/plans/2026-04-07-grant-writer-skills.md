# grant-writer-skills Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Claude Code plugin that orchestrates grant proposal writing for EU (Horizon Europe, ERC, MSCA) and Romanian (UEFISCDI, PNRR) agencies, with optional codex-plugin-cc and claude-scientific-skills integration.

**Architecture:** Single plugin at `/Users/c/lab/plugins/grant-writer-skills/` with 15 prompt-based skills, 8 Python tools, and 9 agency templates. Markdown-only output. Hub-and-spoke pattern: orchestrator invokes sub-skills, optionally enhanced by companion plugins. State persisted as JSON for cross-session resume.

**Tech Stack:** Python 3.11+, requests, backoff, pyyaml, rich, PyMuPDF/pymupdf4llm. No LaTeX.

---

## File Map

### Plugin Scaffolding
- Create: `grant-writer-skills/.claude-plugin/plugin.json`
- Create: `grant-writer-skills/.claude-plugin/marketplace.json`
- Create: `grant-writer-skills/.claude/settings.json`
- Create: `grant-writer-skills/pyproject.toml`
- Create: `grant-writer-skills/requirements.txt`
- Create: `grant-writer-skills/.gitignore`
- Create: `grant-writer-skills/CLAUDE.md`
- Create: `grant-writer-skills/README.md`
- Create: `grant-writer-skills/LICENSE`

### Python Tools (8 files)
- Create: `grant-writer-skills/tools/__init__.py`
- Create: `grant-writer-skills/tools/config.py`
- Create: `grant-writer-skills/tools/verify_setup.py`
- Create: `grant-writer-skills/tools/state_manager.py`
- Create: `grant-writer-skills/tools/pdf_reader.py`
- Create: `grant-writer-skills/tools/agency_requirements.py`
- Create: `grant-writer-skills/tools/funded_grants.py`
- Create: `grant-writer-skills/tools/compliance_checker.py`
- Create: `grant-writer-skills/tools/budget_calculator.py`

### Agency Templates (9 directories)
- Create: `grant-writer-skills/templates/grant_config.yaml`
- Create: `grant-writer-skills/templates/agencies/horizon_ria/agency.json`
- Create: `grant-writer-skills/templates/agencies/horizon_ria/*.md` (5 templates)
- Create: `grant-writer-skills/templates/agencies/horizon_ia/agency.json`
- Create: `grant-writer-skills/templates/agencies/erc/agency.json`
- Create: `grant-writer-skills/templates/agencies/erc/*.md` (4 templates)
- Create: `grant-writer-skills/templates/agencies/msca_postdoc/agency.json`
- Create: `grant-writer-skills/templates/agencies/msca_doctoral/agency.json`
- Create: `grant-writer-skills/templates/agencies/uefiscdi_pce/agency.json`
- Create: `grant-writer-skills/templates/agencies/uefiscdi_pce/*.md` (6 templates)
- Create: `grant-writer-skills/templates/agencies/uefiscdi_te/agency.json`
- Create: `grant-writer-skills/templates/agencies/uefiscdi_pd/agency.json`
- Create: `grant-writer-skills/templates/agencies/pnrr/agency.json`

### Skills (15 SKILL.md files)
- Create: `grant-writer-skills/skills/grant-writer/SKILL.md`
- Create: `grant-writer-skills/skills/foa-analysis/SKILL.md`
- Create: `grant-writer-skills/skills/landscape/SKILL.md`
- Create: `grant-writer-skills/skills/aims/SKILL.md`
- Create: `grant-writer-skills/skills/literature/SKILL.md`
- Create: `grant-writer-skills/skills/preliminary-data/SKILL.md`
- Create: `grant-writer-skills/skills/proposal/SKILL.md`
- Create: `grant-writer-skills/skills/risk-analysis/SKILL.md`
- Create: `grant-writer-skills/skills/budget/SKILL.md`
- Create: `grant-writer-skills/skills/supporting-docs/SKILL.md`
- Create: `grant-writer-skills/skills/compliance/SKILL.md`
- Create: `grant-writer-skills/skills/review/SKILL.md`
- Create: `grant-writer-skills/skills/codex-review/SKILL.md`
- Create: `grant-writer-skills/skills/resubmission/SKILL.md`
- Create: `grant-writer-skills/skills/revision/SKILL.md`

### Installer & Codex Calibrations
- Create: `grant-writer-skills/scripts/setup.py`
- Modify: `/Users/c/lab/plugins/codex-plugin-cc/plugins/codex/scripts/lib/agency-calibration.mjs` (add msca, uefiscdi, pnrr)

---

## Task 1: Plugin Scaffolding

**Files:**
- Create: `grant-writer-skills/.claude-plugin/plugin.json`
- Create: `grant-writer-skills/.claude-plugin/marketplace.json`
- Create: `grant-writer-skills/.claude/settings.json`
- Create: `grant-writer-skills/pyproject.toml`
- Create: `grant-writer-skills/requirements.txt`
- Create: `grant-writer-skills/.gitignore`
- Create: `grant-writer-skills/tools/__init__.py`
- Create: `grant-writer-skills/LICENSE`

- [ ] **Step 1: Create directory structure**

```bash
cd /Users/c/lab/plugins
mkdir -p grant-writer-skills/{.claude-plugin,.claude,skills,tools,templates/agencies,examples,scripts}
mkdir -p grant-writer-skills/templates/agencies/{horizon_ria,horizon_ia,erc,msca_postdoc,msca_doctoral,uefiscdi_pce,uefiscdi_te,uefiscdi_pd,pnrr}
mkdir -p grant-writer-skills/templates/review_fewshot
mkdir -p grant-writer-skills/skills/{grant-writer,foa-analysis,landscape,aims,literature,preliminary-data,proposal,risk-analysis,budget,supporting-docs,compliance,review,codex-review,resubmission,revision}
```

- [ ] **Step 2: Write plugin.json**

Create `grant-writer-skills/.claude-plugin/plugin.json`:

```json
{
  "name": "grant-writer",
  "description": "Grant proposal writing pipeline for EU and Romanian funding agencies. Orchestrates ideation, writing, budgeting, compliance, and multi-model peer review.",
  "version": "0.1.0",
  "author": {
    "name": "Grant Writer Skills Contributors"
  }
}
```

- [ ] **Step 3: Write marketplace.json**

Create `grant-writer-skills/.claude-plugin/marketplace.json`:

```json
{
  "name": "grant-writer-skills",
  "owner": {
    "name": "stamate"
  },
  "metadata": {
    "description": "Grant proposal writing pipeline for EU and Romanian funding agencies. Orchestrates ideation, writing, budgeting, compliance, and multi-model peer review.",
    "version": "0.1.0"
  },
  "plugins": [
    {
      "name": "grant-writer",
      "description": "Full grant proposal pipeline: FOA analysis, competitive landscape, aims refinement, proposal writing, budget, compliance, and agency-calibrated review.",
      "source": "./",
      "skills": [
        "./skills/grant-writer",
        "./skills/foa-analysis",
        "./skills/landscape",
        "./skills/aims",
        "./skills/literature",
        "./skills/preliminary-data",
        "./skills/proposal",
        "./skills/risk-analysis",
        "./skills/budget",
        "./skills/supporting-docs",
        "./skills/compliance",
        "./skills/review",
        "./skills/codex-review",
        "./skills/resubmission",
        "./skills/revision"
      ]
    }
  ]
}
```

- [ ] **Step 4: Write settings.json**

Create `grant-writer-skills/.claude/settings.json`:

```json
{
  "skills": {
    "grant-writer": {
      "type": "prompt",
      "path": "skills/grant-writer/SKILL.md"
    },
    "grant-writer:foa-analysis": {
      "type": "prompt",
      "path": "skills/foa-analysis/SKILL.md"
    },
    "grant-writer:landscape": {
      "type": "prompt",
      "path": "skills/landscape/SKILL.md"
    },
    "grant-writer:aims": {
      "type": "prompt",
      "path": "skills/aims/SKILL.md"
    },
    "grant-writer:literature": {
      "type": "prompt",
      "path": "skills/literature/SKILL.md"
    },
    "grant-writer:preliminary-data": {
      "type": "prompt",
      "path": "skills/preliminary-data/SKILL.md"
    },
    "grant-writer:proposal": {
      "type": "prompt",
      "path": "skills/proposal/SKILL.md"
    },
    "grant-writer:risk-analysis": {
      "type": "prompt",
      "path": "skills/risk-analysis/SKILL.md"
    },
    "grant-writer:budget": {
      "type": "prompt",
      "path": "skills/budget/SKILL.md"
    },
    "grant-writer:supporting-docs": {
      "type": "prompt",
      "path": "skills/supporting-docs/SKILL.md"
    },
    "grant-writer:compliance": {
      "type": "prompt",
      "path": "skills/compliance/SKILL.md"
    },
    "grant-writer:review": {
      "type": "prompt",
      "path": "skills/review/SKILL.md"
    },
    "grant-writer:codex-review": {
      "type": "prompt",
      "path": "skills/codex-review/SKILL.md"
    },
    "grant-writer:resubmission": {
      "type": "prompt",
      "path": "skills/resubmission/SKILL.md"
    },
    "grant-writer:revision": {
      "type": "prompt",
      "path": "skills/revision/SKILL.md"
    }
  }
}
```

- [ ] **Step 5: Write pyproject.toml**

Create `grant-writer-skills/pyproject.toml`:

```toml
[build-system]
requires = ["setuptools>=68.0", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "grant-writer-skills"
version = "0.1.0"
description = "Grant proposal writing pipeline for EU and Romanian funding agencies"
readme = "README.md"
requires-python = ">=3.11"
license = {file = "LICENSE"}
authors = [
    {name = "Grant Writer Skills Contributors"},
]
keywords = ["grants", "research-funding", "claude-code", "skills", "horizon-europe", "erc", "uefiscdi"]
classifiers = [
    "Development Status :: 3 - Alpha",
    "Intended Audience :: Science/Research",
    "Programming Language :: Python :: 3",
    "Programming Language :: Python :: 3.11",
    "Programming Language :: Python :: 3.12",
    "Topic :: Scientific/Engineering",
]
dependencies = [
    "requests>=2.31",
    "backoff>=2.2",
    "pymupdf4llm>=0.0.5",
    "PyMuPDF>=1.23",
    "pyyaml>=6.0",
    "rich>=13.0",
]

[project.urls]
Homepage = "https://github.com/stamate/grant-writer-skills"
Repository = "https://github.com/stamate/grant-writer-skills"

[tool.setuptools.packages.find]
include = ["tools*"]
```

- [ ] **Step 6: Write requirements.txt**

Create `grant-writer-skills/requirements.txt`:

```
# HTTP & API
requests>=2.31
backoff>=2.2

# PDF processing (input only — FOAs and evaluation reports)
pymupdf4llm>=0.0.5
PyMuPDF>=1.23

# Configuration
pyyaml>=6.0

# Terminal output
rich>=13.0
```

- [ ] **Step 7: Write .gitignore**

Create `grant-writer-skills/.gitignore`:

```
# Python
__pycache__/
*.py[cod]
*$py.class
*.egg-info/
dist/
build/
*.egg

# Proposals output
proposals/

# Environment
.env
.venv/
venv/

# IDE
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db
```

- [ ] **Step 8: Write tools/__init__.py**

Create `grant-writer-skills/tools/__init__.py`:

```python
"""Grant Writer tools for Claude Code skills package."""
```

- [ ] **Step 9: Write LICENSE**

Create `grant-writer-skills/LICENSE` with MIT license:

```
MIT License

Copyright (c) 2026 Grant Writer Skills Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 10: Initialize git repo**

```bash
cd /Users/c/lab/plugins/grant-writer-skills && git init
```

- [ ] **Step 11: Commit scaffolding**

```bash
cd /Users/c/lab/plugins/grant-writer-skills
git add .
git commit -m "feat: initial plugin scaffolding with 15 skill registrations"
```

---

## Task 2: Core Tools — config.py + verify_setup.py + pdf_reader.py

**Files:**
- Create: `grant-writer-skills/tools/config.py`
- Create: `grant-writer-skills/tools/verify_setup.py`
- Create: `grant-writer-skills/tools/pdf_reader.py`
- Create: `grant-writer-skills/templates/grant_config.yaml`

- [ ] **Step 1: Write config.py**

Create `grant-writer-skills/tools/config.py`. This follows the ai-scientist-skills nested dataclass pattern but with grant-specific fields:

```python
"""Configuration loading and defaults for Grant Writer."""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Optional

import yaml


@dataclass
class AimsConfig:
    max_refinement_rounds: int = 5
    score_threshold: int = 4        # out of 5 (EU scale)
    codex_review_rounds: int = 2


@dataclass
class LiteratureConfig:
    max_search_rounds: int = 3
    min_citations: int = 30


@dataclass
class WritingConfig:
    reflection_rounds: int = 3


@dataclass
class BudgetConfig:
    indirect_rate: float = 0.25     # 25% flat rate for Horizon Europe
    currency: str = "EUR"


@dataclass
class ReviewConfig:
    revision_cycles: int = 2
    score_threshold: int = 3        # out of 5 (EU threshold)


@dataclass
class ScientificSkillsConfig:
    enabled: str = "auto"
    enhanced_literature: bool = True
    enhanced_writing: bool = True
    enhanced_figures: bool = True
    enhanced_review: bool = True

    def __post_init__(self):
        self.enabled = str(self.enabled).lower()


@dataclass
class CodexConfig:
    enabled: str = "auto"
    panel_review: bool = True
    aims_review: bool = True
    rescue_on_stuck: bool = True
    agency: str = "auto"

    def __post_init__(self):
        self.enabled = str(self.enabled).lower()


@dataclass
class ProposalConfig:
    title: str = ""
    pi_name: str = ""
    institution: str = ""
    acronym: str = ""


@dataclass
class Config:
    agency: str = "horizon"
    mechanism: str = "ria"
    language: str = "en"

    proposal: ProposalConfig = field(default_factory=ProposalConfig)
    aims: AimsConfig = field(default_factory=AimsConfig)
    literature: LiteratureConfig = field(default_factory=LiteratureConfig)
    writing: WritingConfig = field(default_factory=WritingConfig)
    budget: BudgetConfig = field(default_factory=BudgetConfig)
    review: ReviewConfig = field(default_factory=ReviewConfig)
    scientific_skills: ScientificSkillsConfig = field(default_factory=ScientificSkillsConfig)
    codex: CodexConfig = field(default_factory=CodexConfig)


def _nested_dataclass_from_dict(cls, data: dict):
    """Recursively instantiate a dataclass from a dict."""
    if not isinstance(data, dict):
        return data
    fieldtypes = {f.name: f.type for f in cls.__dataclass_fields__.values()}
    kwargs = {}
    for k, v in data.items():
        if k in fieldtypes:
            ft = fieldtypes[k]
            # Resolve string type annotations
            if isinstance(ft, str):
                ft = eval(ft)
            if hasattr(ft, "__dataclass_fields__") and isinstance(v, dict):
                kwargs[k] = _nested_dataclass_from_dict(ft, v)
            else:
                kwargs[k] = v
    return cls(**kwargs)


def _deep_merge(base: dict, override: dict) -> dict:
    """Deep merge override into base dict."""
    result = base.copy()
    for k, v in override.items():
        if k in result and isinstance(result[k], dict) and isinstance(v, dict):
            result[k] = _deep_merge(result[k], v)
        else:
            result[k] = v
    return result


def load_config(config_path: str | None = None, overrides: dict | None = None) -> Config:
    """Load config from YAML file with optional overrides."""
    default_path = Path(__file__).resolve().parent.parent / "templates" / "grant_config.yaml"
    path = Path(config_path) if config_path else default_path

    data = {}
    if path.exists():
        data = yaml.safe_load(path.read_text()) or {}

    if overrides:
        data = _deep_merge(data, overrides)

    return _nested_dataclass_from_dict(Config, data)


def save_config(config: Config, path: str) -> None:
    """Save config to YAML file."""
    data = asdict(config)
    Path(path).write_text(yaml.dump(data, default_flow_style=False, sort_keys=False))


def parse_config_args() -> Config:
    """CLI entry point: load and display config."""
    parser = argparse.ArgumentParser(description="Grant Writer configuration")
    parser.add_argument("--config", type=str, help="Path to config YAML")
    parser.add_argument("--set", nargs="*", metavar="KEY=VAL",
                        help="Override config values (e.g. agency=erc codex.enabled=false)")
    args = parser.parse_args()

    overrides = {}
    if args.set:
        for kv in args.set:
            key, val = kv.split("=", 1)
            parts = key.split(".")
            d = overrides
            for p in parts[:-1]:
                d = d.setdefault(p, {})
            # Auto-convert types
            if val.lower() in ("true", "false"):
                val = val.lower() == "true"
            elif val.isdigit():
                val = int(val)
            else:
                try:
                    val = float(val)
                except ValueError:
                    pass
            d[parts[-1]] = val

    config = load_config(args.config, overrides)
    print(yaml.dump(asdict(config), default_flow_style=False, sort_keys=False))
    return config


if __name__ == "__main__":
    parse_config_args()
```

- [ ] **Step 2: Write grant_config.yaml**

Create `grant-writer-skills/templates/grant_config.yaml`:

```yaml
# Grant Writer — Default Configuration
# EU and Romanian funding agencies.

# ── Agency & mechanism ───────────────────────────────────────────────────────
agency: horizon
mechanism: ria
language: en                 # en | ro (Romanian templates only)

# ── Proposal metadata ────────────────────────────────────────────────────────
proposal:
  title: ""
  pi_name: ""
  institution: ""
  acronym: ""                # EU proposals need a project acronym

# ── Aims / objectives refinement ─────────────────────────────────────────────
aims:
  max_refinement_rounds: 5
  score_threshold: 4         # out of 5 (EU scale)
  codex_review_rounds: 2

# ── Literature search ────────────────────────────────────────────────────────
literature:
  max_search_rounds: 3
  min_citations: 30

# ── Proposal writing ─────────────────────────────────────────────────────────
writing:
  reflection_rounds: 3

# ── Budget ───────────────────────────────────────────────────────────────────
budget:
  indirect_rate: 0.25        # 25% flat rate for Horizon Europe
  currency: EUR              # EUR | RON

# ── Review & revision ────────────────────────────────────────────────────────
review:
  revision_cycles: 2
  score_threshold: 3         # out of 5 (EU: threshold for funding)

# ── Scientific skills (optional — requires claude-scientific-skills plugin) ──
scientific_skills:
  enabled: auto              # auto | true | false
  enhanced_literature: true
  enhanced_writing: true
  enhanced_figures: true
  enhanced_review: true

# ── Codex integration (optional — requires codex-plugin-cc) ─────────────────
codex:
  enabled: auto              # auto | true | false
  panel_review: true
  aims_review: true
  rescue_on_stuck: true
  agency: auto               # auto (from top-level agency) | horizon | erc | msca | uefiscdi | pnrr
```

- [ ] **Step 3: Write verify_setup.py**

Create `grant-writer-skills/tools/verify_setup.py`:

```python
"""Verify all prerequisites for Grant Writer Skills.

Run after installation to ensure the environment is ready:
    python3 tools/verify_setup.py
"""

from __future__ import annotations

import importlib
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
RESET = "\033[0m"
CHECK = f"{GREEN}\u2713{RESET}"
CROSS = f"{RED}\u2717{RESET}"
WARN = f"{YELLOW}!{RESET}"

IMPORT_MAP = {
    "PyMuPDF": "fitz",
    "pyyaml": "yaml",
    "pymupdf4llm": "pymupdf4llm",
}


def parse_requirements() -> list[tuple[str, str]]:
    req_file = Path(__file__).resolve().parent.parent / "requirements.txt"
    packages = []
    if not req_file.exists():
        print(f"  {WARN} requirements.txt not found")
        return packages
    for line in req_file.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        name = re.split(r"[><=!~\[]", line)[0].strip()
        imp = IMPORT_MAP.get(name, name)
        packages.append((name, imp))
    return packages


def check_python() -> bool:
    v = sys.version_info
    ok = v >= (3, 11)
    status = CHECK if ok else CROSS
    print(f"  {status} Python {v.major}.{v.minor}.{v.micro}", end="")
    if not ok:
        print(f"  (requires 3.11+)", end="")
    print()
    return ok


def check_package(name: str, import_name: str) -> bool:
    try:
        m = importlib.import_module(import_name)
        ver = getattr(m, "__version__", "ok")
        print(f"  {CHECK} {name} {ver}")
        return True
    except ImportError:
        print(f"  {CROSS} {name}  (pip install {name})")
        return False


def check_claude_code() -> bool:
    ok = shutil.which("claude") is not None
    status = CHECK if ok else CROSS
    print(f"  {status} Claude Code CLI")
    return ok


def check_codex() -> tuple[bool, bool, bool]:
    cli = shutil.which("codex") is not None
    plugin = False
    auth = False

    if cli:
        # Check plugin
        try:
            result = subprocess.run(
                ["find", os.path.expanduser("~/.claude/plugins"), ".claude/plugins",
                 "-maxdepth", "5", "-name", "plugin.json",
                 "-exec", "grep", "-l", "codex", "{}", ";"],
                capture_output=True, text=True, timeout=10,
            )
            plugin = bool(result.stdout.strip())
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

        # Check auth
        if plugin:
            try:
                result = subprocess.run(
                    ["codex", "login", "status"],
                    capture_output=True, text=True, timeout=10,
                )
                auth = result.returncode == 0
            except (subprocess.TimeoutExpired, FileNotFoundError):
                pass

    status_cli = CHECK if cli else WARN
    print(f"  {status_cli} Codex CLI {'found' if cli else 'not found (optional)'}")
    if cli:
        status_plugin = CHECK if plugin else WARN
        print(f"  {status_plugin} codex-plugin-cc {'installed' if plugin else 'not installed'}")
        if plugin:
            status_auth = CHECK if auth else WARN
            print(f"  {status_auth} Codex auth {'ok' if auth else 'not authenticated'}")

    return cli, plugin, auth


def check_scientific_skills() -> bool:
    try:
        result = subprocess.run(
            ["find", os.path.expanduser("~/.claude/plugins"), ".claude/plugins",
             "-maxdepth", "5", "-name", "plugin.json",
             "-exec", "grep", "-l", "claude-scientific", "{}", ";"],
            capture_output=True, text=True, timeout=10,
        )
        found = bool(result.stdout.strip())
    except (subprocess.TimeoutExpired, FileNotFoundError):
        found = False

    status = CHECK if found else WARN
    print(f"  {status} claude-scientific-skills {'installed' if found else 'not installed (optional)'}")
    return found


def check_s2_api() -> bool:
    key = bool(os.getenv("S2_API_KEY"))
    status = CHECK if key else WARN
    print(f"  {status} S2_API_KEY {'set' if key else 'not set (optional, enables higher rate limits)'}")
    return key


def main():
    print("\nGrant Writer Skills — Environment Check\n")
    all_ok = True

    print("Python:")
    all_ok &= check_python()

    print("\nPackages:")
    for name, imp in parse_requirements():
        all_ok &= check_package(name, imp)

    print("\nClaude Code:")
    all_ok &= check_claude_code()

    print("\nOptional integrations:")
    check_codex()
    check_scientific_skills()
    check_s2_api()

    print()
    if all_ok:
        print(f"{CHECK} All required checks passed. Ready to write grants!")
    else:
        print(f"{CROSS} Some required checks failed. Fix issues above before continuing.")
    print()

    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Write pdf_reader.py**

Create `grant-writer-skills/tools/pdf_reader.py`:

```python
"""PDF text extraction for input documents (FOAs, evaluation reports).

Used to parse funding opportunity announcements and previous reviewer feedback.
Not used for output — all proposal output is Markdown.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Optional


def extract_text(pdf_path: str, max_pages: Optional[int] = None) -> str:
    """Extract text from a PDF file.

    Tries pymupdf4llm first (Markdown formatting), falls back to PyMuPDF, then pypdf.
    """
    path = Path(pdf_path)
    if not path.exists():
        raise FileNotFoundError(f"PDF not found: {pdf_path}")

    # Try pymupdf4llm (Markdown-formatted output)
    try:
        import pymupdf4llm
        text = pymupdf4llm.to_markdown(str(path))
        if max_pages:
            pages = _split_pages(text)
            text = "\n\n".join(pages[:max_pages])
        return text
    except ImportError:
        pass

    # Fall back to PyMuPDF plain text
    try:
        import fitz
        doc = fitz.open(str(path))
        texts = []
        page_limit = max_pages or len(doc)
        for i in range(min(page_limit, len(doc))):
            texts.append(doc[i].get_text())
        doc.close()
        return "\n\n".join(texts)
    except ImportError:
        pass

    # Last resort: pypdf
    try:
        from pypdf import PdfReader
        reader = PdfReader(str(path))
        texts = []
        page_limit = max_pages or len(reader.pages)
        for i in range(min(page_limit, len(reader.pages))):
            text = reader.pages[i].extract_text()
            if text:
                texts.append(text)
        return "\n\n".join(texts)
    except ImportError:
        raise RuntimeError(
            "No PDF library available. Install one of: pymupdf4llm, PyMuPDF, pypdf"
        )


def get_page_count(pdf_path: str) -> int:
    """Return the number of pages in a PDF."""
    path = Path(pdf_path)
    if not path.exists():
        raise FileNotFoundError(f"PDF not found: {pdf_path}")

    try:
        import fitz
        doc = fitz.open(str(path))
        count = len(doc)
        doc.close()
        return count
    except ImportError:
        pass

    try:
        from pypdf import PdfReader
        return len(PdfReader(str(path)).pages)
    except ImportError:
        raise RuntimeError("No PDF library available.")


def _split_pages(text: str) -> list[str]:
    """Split text by form feed characters or page markers."""
    if "\f" in text:
        return text.split("\f")
    return [text]


def main():
    parser = argparse.ArgumentParser(description="Extract text from PDF")
    parser.add_argument("pdf_path", help="Path to PDF file")
    parser.add_argument("--pages", type=int, help="Max pages to extract")
    parser.add_argument("--count", action="store_true", help="Just print page count")
    args = parser.parse_args()

    if args.count:
        print(get_page_count(args.pdf_path))
    else:
        print(extract_text(args.pdf_path, args.pages))


if __name__ == "__main__":
    main()
```

- [ ] **Step 5: Verify tools load correctly**

```bash
cd /Users/c/lab/plugins/grant-writer-skills
python3 tools/config.py --config templates/grant_config.yaml
python3 tools/verify_setup.py
```

Expected: config prints YAML, verify_setup shows check results.

- [ ] **Step 6: Commit**

```bash
cd /Users/c/lab/plugins/grant-writer-skills
git add tools/ templates/grant_config.yaml
git commit -m "feat: add core tools — config, verify_setup, pdf_reader"
```

---

## Task 3: State Manager

**Files:**
- Create: `grant-writer-skills/tools/state_manager.py`

- [ ] **Step 1: Write state_manager.py**

Create `grant-writer-skills/tools/state_manager.py`:

```python
"""Grant proposal state management — JSON-based persistence.

Tracks pipeline progress across sessions. Simpler than ai-scientist-skills
BFTS state manager — no tree search, just phase tracking and section completion.
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional

import yaml


PHASE_ORDER = [
    "setup",
    "foa_analysis",
    "landscape",
    "aims",
    "literature",
    "preliminary_data",
    "proposal_writing",
    "risk_analysis",
    "budget",
    "supporting_docs",
    "compliance",
    "assembly",
    "review",
    "revision",
]


def create_state(agency: str, mechanism: str, language: str = "en") -> dict:
    """Create initial proposal state."""
    phases = {}
    for phase in PHASE_ORDER:
        phases[phase] = {"status": "pending"}
    return {
        "agency": agency,
        "mechanism": mechanism,
        "language": language,
        "current_phase": "setup",
        "phases": phases,
        "config": {},
        "created_at": datetime.now().isoformat(),
        "updated_at": datetime.now().isoformat(),
    }


def init_proposal(agency: str, mechanism: str, config_path: Optional[str] = None,
                   language: str = "en") -> str:
    """Initialize a new proposal directory. Returns the proposal path."""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    proposal_dir = Path("proposals") / f"{agency}_{mechanism}_{timestamp}"
    proposal_dir.mkdir(parents=True, exist_ok=True)

    # Create subdirectories
    for subdir in ["landscape", "sections/figures", "budget", "supporting/letters",
                   "review", "resubmission", "final"]:
        (proposal_dir / subdir).mkdir(parents=True, exist_ok=True)

    # Save state
    state = create_state(agency, mechanism, language)
    (proposal_dir / "state.json").write_text(json.dumps(state, indent=2))

    # Copy config
    if config_path:
        config_data = yaml.safe_load(Path(config_path).read_text())
    else:
        default_config = Path(__file__).resolve().parent.parent / "templates" / "grant_config.yaml"
        config_data = yaml.safe_load(default_config.read_text())
    config_data["agency"] = agency
    config_data["mechanism"] = mechanism
    config_data["language"] = language
    (proposal_dir / "config.yaml").write_text(
        yaml.dump(config_data, default_flow_style=False, sort_keys=False)
    )

    print(str(proposal_dir))
    return str(proposal_dir)


def load_state(proposal_dir: str) -> dict:
    """Load proposal state from directory."""
    state_path = Path(proposal_dir) / "state.json"
    if not state_path.exists():
        raise FileNotFoundError(f"No state.json in {proposal_dir}")
    return json.loads(state_path.read_text())


def save_state(proposal_dir: str, state: dict) -> None:
    """Save proposal state to directory."""
    state["updated_at"] = datetime.now().isoformat()
    state_path = Path(proposal_dir) / "state.json"
    state_path.write_text(json.dumps(state, indent=2))


def update_phase(proposal_dir: str, phase: str, status: str, **extra) -> dict:
    """Update a phase's status. Extra kwargs are merged into the phase dict."""
    state = load_state(proposal_dir)
    if phase not in state["phases"]:
        raise ValueError(f"Unknown phase: {phase}. Valid: {list(state['phases'].keys())}")
    state["phases"][phase]["status"] = status
    state["phases"][phase].update(extra)
    if status == "in_progress":
        state["current_phase"] = phase
    elif status == "complete":
        # Advance current_phase to next pending
        idx = PHASE_ORDER.index(phase)
        for next_phase in PHASE_ORDER[idx + 1:]:
            if state["phases"][next_phase]["status"] == "pending":
                state["current_phase"] = next_phase
                break
    save_state(proposal_dir, state)
    return state


def get_resume_phase(proposal_dir: str) -> str:
    """Find the first incomplete phase for resume."""
    state = load_state(proposal_dir)
    for phase in PHASE_ORDER:
        if state["phases"][phase]["status"] != "complete":
            return phase
    return "complete"


def get_sections_status(proposal_dir: str) -> dict:
    """Check which section .md files exist in sections/."""
    sections_dir = Path(proposal_dir) / "sections"
    result = {}
    if sections_dir.exists():
        for md_file in sorted(sections_dir.glob("*.md")):
            word_count = len(md_file.read_text().split())
            result[md_file.stem] = {"exists": True, "words": word_count}
    return result


def print_status(proposal_dir: str) -> None:
    """Print human-readable proposal status."""
    state = load_state(proposal_dir)
    print(f"\nProposal: {proposal_dir}")
    print(f"Agency: {state['agency']} / {state['mechanism']}")
    print(f"Language: {state['language']}")
    print(f"Current phase: {state['current_phase']}")
    print(f"Created: {state['created_at']}")
    print(f"Updated: {state['updated_at']}")
    print(f"\nPhases:")
    for phase in PHASE_ORDER:
        info = state["phases"][phase]
        status = info["status"]
        icon = "\u2713" if status == "complete" else "\u2192" if status == "in_progress" else " "
        extra = ""
        if "sections_done" in info:
            extra = f" ({len(info['sections_done'])} sections done)"
        if "rounds" in info:
            extra = f" ({info['rounds']} rounds)"
        if "citations" in info:
            extra = f" ({info['citations']} citations)"
        print(f"  [{icon}] {phase}: {status}{extra}")

    sections = get_sections_status(proposal_dir)
    if sections:
        print(f"\nSections:")
        for name, info in sections.items():
            print(f"  - {name}.md ({info['words']} words)")


def main():
    parser = argparse.ArgumentParser(description="Grant proposal state management")
    sub = parser.add_subparsers(dest="command")

    p_init = sub.add_parser("init", help="Initialize new proposal")
    p_init.add_argument("--agency", required=True)
    p_init.add_argument("--mechanism", required=True)
    p_init.add_argument("--config", type=str)
    p_init.add_argument("--lang", default="en")

    p_status = sub.add_parser("status", help="Show proposal status")
    p_status.add_argument("proposal_dir")

    p_update = sub.add_parser("update", help="Update phase status")
    p_update.add_argument("proposal_dir")
    p_update.add_argument("--phase", required=True)
    p_update.add_argument("--status", required=True, choices=["pending", "in_progress", "complete"])

    p_resume = sub.add_parser("resume", help="Find resume point")
    p_resume.add_argument("proposal_dir")

    p_sections = sub.add_parser("sections", help="List section files and word counts")
    p_sections.add_argument("proposal_dir")

    args = parser.parse_args()

    if args.command == "init":
        init_proposal(args.agency, args.mechanism, args.config, args.lang)
    elif args.command == "status":
        print_status(args.proposal_dir)
    elif args.command == "update":
        update_phase(args.proposal_dir, args.phase, args.status)
        print(f"Updated {args.phase} → {args.status}")
    elif args.command == "resume":
        phase = get_resume_phase(args.proposal_dir)
        print(phase)
    elif args.command == "sections":
        sections = get_sections_status(args.proposal_dir)
        print(json.dumps(sections, indent=2))
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Test state_manager.py**

```bash
cd /Users/c/lab/plugins/grant-writer-skills
python3 tools/state_manager.py init --agency horizon --mechanism ria
# Should print: proposals/horizon_ria_<timestamp>
```

```bash
python3 tools/state_manager.py status proposals/horizon_ria_*
# Should print status with all phases pending
```

- [ ] **Step 3: Commit**

```bash
cd /Users/c/lab/plugins/grant-writer-skills
git add tools/state_manager.py
git commit -m "feat: add state manager with phase tracking and resume support"
```

---

## Task 4: Agency Requirements + Templates

**Files:**
- Create: `grant-writer-skills/tools/agency_requirements.py`
- Create: 9 `agency.json` files + Markdown templates for key agencies

- [ ] **Step 1: Write agency_requirements.py**

Create `grant-writer-skills/tools/agency_requirements.py`:

```python
"""Agency requirements database. Loads agency.json manifests from templates."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Optional


TEMPLATES_DIR = Path(__file__).resolve().parent.parent / "templates" / "agencies"


def list_agencies() -> list[dict]:
    """List all available agency templates."""
    agencies = []
    for agency_dir in sorted(TEMPLATES_DIR.iterdir()):
        manifest = agency_dir / "agency.json"
        if manifest.exists():
            data = json.loads(manifest.read_text())
            agencies.append({
                "key": agency_dir.name,
                "agency": data.get("agency", ""),
                "mechanism": data.get("mechanism", ""),
                "name": data.get("name", ""),
                "region": data.get("region", ""),
            })
    return agencies


def load_agency(agency_key: str) -> dict:
    """Load agency.json for a specific template directory name."""
    manifest = TEMPLATES_DIR / agency_key / "agency.json"
    if not manifest.exists():
        # Try matching agency+mechanism pattern
        for d in TEMPLATES_DIR.iterdir():
            m = d / "agency.json"
            if m.exists():
                data = json.loads(m.read_text())
                if data.get("agency") == agency_key:
                    return data
        raise FileNotFoundError(f"No agency template found for: {agency_key}")
    return json.loads(manifest.read_text())


def find_agency(agency: str, mechanism: str) -> dict:
    """Find agency.json matching agency + mechanism."""
    # Try direct directory name match
    candidates = [
        f"{agency}_{mechanism}",
        f"{agency}",
        mechanism,
    ]
    for name in candidates:
        manifest = TEMPLATES_DIR / name / "agency.json"
        if manifest.exists():
            return json.loads(manifest.read_text())

    # Scan all templates
    for d in TEMPLATES_DIR.iterdir():
        m = d / "agency.json"
        if m.exists():
            data = json.loads(m.read_text())
            if data.get("agency") == agency and data.get("mechanism", "").lower() == mechanism.lower():
                return data

    raise FileNotFoundError(f"No template for agency={agency} mechanism={mechanism}")


def get_sections(agency_key: str) -> list[dict]:
    """Get section definitions for an agency template."""
    data = load_agency(agency_key)
    return data.get("sections", [])


def get_budget_rules(agency_key: str) -> dict:
    """Get budget rules for an agency template."""
    data = load_agency(agency_key)
    return data.get("budget", {})


def get_review_criteria(agency_key: str) -> list[str]:
    """Get review criteria for an agency template."""
    data = load_agency(agency_key)
    return data.get("review_criteria", [])


def get_section_templates(agency_key: str) -> dict[str, str]:
    """Load Markdown template files for an agency."""
    agency_dir = TEMPLATES_DIR / agency_key
    templates = {}
    for md_file in sorted(agency_dir.glob("*.md")):
        templates[md_file.stem] = md_file.read_text()
    return templates


def main():
    parser = argparse.ArgumentParser(description="Agency requirements database")
    sub = parser.add_subparsers(dest="command")

    sub.add_parser("list", help="List all agency templates")

    p_info = sub.add_parser("info", help="Show agency info")
    p_info.add_argument("agency")
    p_info.add_argument("mechanism", nargs="?", default="")

    p_sections = sub.add_parser("sections", help="Show section limits")
    p_sections.add_argument("agency")
    p_sections.add_argument("mechanism", nargs="?", default="")

    p_budget = sub.add_parser("budget", help="Show budget rules")
    p_budget.add_argument("agency")
    p_budget.add_argument("mechanism", nargs="?", default="")

    p_criteria = sub.add_parser("review-criteria", help="Show review criteria")
    p_criteria.add_argument("agency")
    p_criteria.add_argument("mechanism", nargs="?", default="")

    args = parser.parse_args()

    if args.command == "list":
        for a in list_agencies():
            print(f"  {a['key']:20s}  {a['name']}  ({a['region']})")
    elif args.command == "info":
        key = f"{args.agency}_{args.mechanism}" if args.mechanism else args.agency
        data = load_agency(key)
        print(json.dumps(data, indent=2))
    elif args.command == "sections":
        key = f"{args.agency}_{args.mechanism}" if args.mechanism else args.agency
        for s in get_sections(key):
            limit = f"{s['words']} words" if s.get("words") else "no limit"
            req = "required" if s.get("required") else "optional"
            print(f"  {s['name']:30s}  {limit:15s}  {req}")
    elif args.command == "budget":
        key = f"{args.agency}_{args.mechanism}" if args.mechanism else args.agency
        print(json.dumps(get_budget_rules(key), indent=2))
    elif args.command == "review-criteria":
        key = f"{args.agency}_{args.mechanism}" if args.mechanism else args.agency
        for c in get_review_criteria(key):
            print(f"  - {c}")
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Write agency.json for Horizon Europe RIA**

Create `grant-writer-skills/templates/agencies/horizon_ria/agency.json`:

```json
{
  "agency": "horizon",
  "mechanism": "RIA",
  "name": "Horizon Europe Research & Innovation Action",
  "region": "eu",
  "language": ["en"],
  "sections": [
    {"name": "project_summary", "words": 2000, "required": true},
    {"name": "excellence", "words": 10000, "required": true, "subsections": ["objectives", "methodology", "ambition"]},
    {"name": "impact", "words": 8000, "required": true, "subsections": ["outcomes", "dissemination", "exploitation"]},
    {"name": "implementation", "words": 10000, "required": true, "subsections": ["work_plan", "management", "consortium", "resources"]},
    {"name": "ethics", "words": null, "required": true},
    {"name": "bibliography", "words": null, "required": true},
    {"name": "cv_pi", "words": null, "required": true, "per_person": true}
  ],
  "formatting": {
    "font": "Times New Roman or equivalent",
    "font_size": 11,
    "margins": "15mm",
    "line_spacing": "single",
    "page_limit": 45
  },
  "budget": {
    "model": "person_months",
    "currency": "EUR",
    "indirect_rate": 0.25,
    "indirect_model": "flat_rate",
    "max_total": null,
    "max_years": null,
    "personnel_unit": "person-months",
    "unit_cost_categories": ["personnel", "subcontracting", "travel", "equipment", "other_goods"]
  },
  "citation_style": "numbered",
  "review_criteria": ["excellence", "impact", "implementation"],
  "review_weights": {"excellence": 50, "impact": 30, "implementation": 20},
  "codex_agency": "horizon"
}
```

- [ ] **Step 3: Write Horizon RIA section templates**

Create `grant-writer-skills/templates/agencies/horizon_ria/project_summary.md`:

```markdown
# Project Summary

<!-- PROJECT ACRONYM: [Acronym] -->
<!-- DURATION: [months] -->
<!-- KEYWORDS: [5-7 keywords] -->

## Abstract

<!-- 2000 words max. Describe the project in a way accessible to non-specialists. -->
<!-- Cover: objectives, methodology, expected impact, consortium added value. -->
```

Create `grant-writer-skills/templates/agencies/horizon_ria/excellence.md`:

```markdown
# 1. Excellence

## 1.1 Objectives and ambition

<!-- State the overall and specific objectives for the project. -->
<!-- Describe the research questions / hypotheses. -->
<!-- Explain how the project goes beyond the state of the art. -->

## 1.2 Methodology

<!-- Describe the overall methodology and approach. -->
<!-- Explain how the methodology addresses the objectives. -->
<!-- Include a Pert/Gantt chart or work flow diagram. -->

![Methodology overview](figures/methodology_flowchart.png)

## 1.3 Originality and innovation

<!-- Describe any novel concepts, approaches, or methods. -->
<!-- Explain how the project is positioned compared to competing approaches. -->
```

Create `grant-writer-skills/templates/agencies/horizon_ria/impact.md`:

```markdown
# 2. Impact

## 2.1 Project's pathways towards impact

<!-- Describe the expected outcomes and impacts. -->
<!-- Map to the expected outcomes of the Horizon Europe Work Programme topic. -->

## 2.2 Measures to maximise impact — Dissemination, exploitation, and communication

<!-- Describe the dissemination and exploitation plan. -->
<!-- Include target groups and channels. -->
<!-- Address open access policy. -->

### Communication activities
### Dissemination activities
### Exploitation activities
```

Create `grant-writer-skills/templates/agencies/horizon_ria/implementation.md`:

```markdown
# 3. Implementation

## 3.1 Work plan — Work packages, deliverables, and milestones

<!-- Describe work packages with objectives, tasks, deliverables. -->
<!-- Include a Gantt chart. -->

![Work plan Gantt chart](figures/gantt_chart.png)

### Work Package 1: [Title]
- **Lead**: [Partner]
- **Person-months**: [N]
- **Objectives**: ...
- **Tasks**: ...
- **Deliverables**: ...

## 3.2 Management structure, milestones, and procedures

<!-- Describe the management structure and decision-making. -->
<!-- List milestones with verification means. -->

## 3.3 Consortium as a whole

<!-- Describe the consortium composition and added value. -->
<!-- Explain complementarity of partners. -->

## 3.4 Resources to be committed

<!-- Overview of personnel, equipment, and budget allocation. -->
```

- [ ] **Step 4: Write agency.json for ERC**

Create `grant-writer-skills/templates/agencies/erc/agency.json`:

```json
{
  "agency": "erc",
  "mechanism": "Starting/Consolidator/Advanced",
  "name": "European Research Council Grant",
  "region": "eu",
  "language": ["en"],
  "sections": [
    {"name": "project_summary", "words": 500, "required": true},
    {"name": "extended_synopsis", "words": 2500, "required": true},
    {"name": "scientific_proposal", "words": 7500, "required": true},
    {"name": "cv_pi", "words": null, "required": true},
    {"name": "track_record", "words": null, "required": true},
    {"name": "bibliography", "words": null, "required": true}
  ],
  "formatting": {
    "font": "Times New Roman or equivalent",
    "font_size": 11,
    "margins": "15mm",
    "line_spacing": "single",
    "page_limit_synopsis": 5,
    "page_limit_proposal": 15
  },
  "budget": {
    "model": "person_months",
    "currency": "EUR",
    "indirect_rate": 0.25,
    "indirect_model": "flat_rate",
    "max_total_starting": 1500000,
    "max_total_consolidator": 2000000,
    "max_total_advanced": 2500000,
    "max_years": 5,
    "personnel_unit": "person-months"
  },
  "citation_style": "numbered",
  "review_criteria": ["groundbreaking_nature", "methodology", "pi_capability"],
  "codex_agency": "erc"
}
```

- [ ] **Step 5: Write agency.json for UEFISCDI PCE**

Create `grant-writer-skills/templates/agencies/uefiscdi_pce/agency.json`:

```json
{
  "agency": "uefiscdi",
  "mechanism": "PCE",
  "name": "UEFISCDI Exploratory Research Projects (PCE)",
  "region": "romania",
  "language": ["en", "ro"],
  "sections": [
    {"name": "project_summary", "words": 500, "required": true},
    {"name": "state_of_the_art", "words": 2000, "required": true},
    {"name": "objectives", "words": 1500, "required": true},
    {"name": "methodology", "words": 3000, "required": true},
    {"name": "work_plan", "words": 1000, "required": true},
    {"name": "expected_results", "words": 1000, "required": true},
    {"name": "budget_justification", "words": null, "required": true},
    {"name": "bibliography", "words": null, "required": true},
    {"name": "cv_pi", "words": null, "required": true, "per_person": true}
  ],
  "formatting": {
    "font": "Times New Roman",
    "font_size": 12,
    "margins": "25mm",
    "line_spacing": "1.5"
  },
  "budget": {
    "model": "monthly_salary",
    "currency": "RON",
    "indirect_rate_cap": 0.25,
    "max_per_year": null,
    "max_total": null,
    "max_years": 3,
    "personnel_unit": "lei/month",
    "categories": ["personnel", "mobility", "equipment", "consumables", "indirect"]
  },
  "citation_style": "numbered",
  "review_criteria": ["scientific_quality", "methodology", "feasibility", "pi_capability", "impact"],
  "codex_agency": "uefiscdi"
}
```

- [ ] **Step 6: Write UEFISCDI PCE section templates**

Create `grant-writer-skills/templates/agencies/uefiscdi_pce/project_summary.md`:

```markdown
# Project Summary

<!-- TITLE: [Project title] -->
<!-- PI: [Name, institution] -->
<!-- DURATION: [months] -->
<!-- KEYWORDS: [5 keywords] -->

## Abstract

<!-- 500 words max. Concise description of objectives, methodology, and expected impact. -->
```

Create `grant-writer-skills/templates/agencies/uefiscdi_pce/state_of_the_art.md`:

```markdown
# State of the Art

<!-- 2000 words max. -->
<!-- Present current knowledge in the field. -->
<!-- Identify gaps and unsolved problems. -->
<!-- Position the proposed research relative to international state of the art. -->
<!-- Cite relevant recent publications (last 5 years). -->
```

Create `grant-writer-skills/templates/agencies/uefiscdi_pce/objectives.md`:

```markdown
# Objectives

<!-- 1500 words max. -->
<!-- State the general objective (long-term goal). -->
<!-- List 3-4 specific objectives (measurable, time-bound). -->
<!-- Explain the novelty and originality of each objective. -->
<!-- Describe the expected contribution to the field. -->
```

Create `grant-writer-skills/templates/agencies/uefiscdi_pce/methodology.md`:

```markdown
# Methodology

<!-- 3000 words max. -->
<!-- Describe the research approach for each objective. -->
<!-- Include experimental design, data collection, analysis methods. -->
<!-- Address feasibility and preliminary results. -->
<!-- Discuss alternative approaches and risk mitigation. -->

![Methodology overview](figures/methodology_flowchart.png)
```

Create `grant-writer-skills/templates/agencies/uefiscdi_pce/work_plan.md`:

```markdown
# Work Plan

<!-- 1000 words max. -->
<!-- Timeline with milestones and deliverables. -->
<!-- Task distribution among team members. -->

![Work plan timeline](figures/gantt_chart.png)

| Year | Quarter | Task | Responsible | Deliverable |
|------|---------|------|-------------|-------------|
| 1 | Q1-Q2 | ... | ... | ... |
```

Create `grant-writer-skills/templates/agencies/uefiscdi_pce/expected_results.md`:

```markdown
# Expected Results

<!-- 1000 words max. -->
<!-- List expected publications (ISI journals, conferences). -->
<!-- Describe potential for innovation and applications. -->
<!-- Discuss broader impact (training, infrastructure, societal). -->
```

- [ ] **Step 7: Write remaining agency.json stubs**

Create `grant-writer-skills/templates/agencies/horizon_ia/agency.json`:

```json
{
  "agency": "horizon",
  "mechanism": "IA",
  "name": "Horizon Europe Innovation Action",
  "region": "eu",
  "language": ["en"],
  "sections": [
    {"name": "project_summary", "words": 2000, "required": true},
    {"name": "excellence", "words": 10000, "required": true},
    {"name": "impact", "words": 8000, "required": true},
    {"name": "implementation", "words": 10000, "required": true},
    {"name": "ethics", "words": null, "required": true},
    {"name": "bibliography", "words": null, "required": true},
    {"name": "cv_pi", "words": null, "required": true, "per_person": true}
  ],
  "formatting": {"font": "Times New Roman", "font_size": 11, "margins": "15mm", "line_spacing": "single", "page_limit": 45},
  "budget": {"model": "person_months", "currency": "EUR", "indirect_rate": 0.25, "indirect_model": "flat_rate", "personnel_unit": "person-months"},
  "citation_style": "numbered",
  "review_criteria": ["excellence", "impact", "implementation"],
  "review_weights": {"excellence": 40, "impact": 40, "implementation": 20},
  "codex_agency": "horizon"
}
```

Create `grant-writer-skills/templates/agencies/msca_postdoc/agency.json`:

```json
{
  "agency": "msca",
  "mechanism": "Postdoctoral Fellowships",
  "name": "MSCA Postdoctoral Fellowships",
  "region": "eu",
  "language": ["en"],
  "sections": [
    {"name": "project_summary", "words": 500, "required": true},
    {"name": "excellence", "words": 5000, "required": true},
    {"name": "impact", "words": 3000, "required": true},
    {"name": "implementation", "words": 2000, "required": true},
    {"name": "cv_researcher", "words": null, "required": true},
    {"name": "supervision_letter", "words": null, "required": true},
    {"name": "bibliography", "words": null, "required": true}
  ],
  "formatting": {"font": "Times New Roman", "font_size": 11, "margins": "15mm", "line_spacing": "single", "page_limit": 10},
  "budget": {"model": "person_months", "currency": "EUR", "indirect_rate": 0.25, "indirect_model": "flat_rate", "personnel_unit": "person-months"},
  "citation_style": "numbered",
  "review_criteria": ["excellence", "impact", "implementation"],
  "review_weights": {"excellence": 50, "impact": 30, "implementation": 20},
  "codex_agency": "msca"
}
```

Create `grant-writer-skills/templates/agencies/msca_doctoral/agency.json`:

```json
{
  "agency": "msca",
  "mechanism": "Doctoral Networks",
  "name": "MSCA Doctoral Networks",
  "region": "eu",
  "language": ["en"],
  "sections": [
    {"name": "project_summary", "words": 2000, "required": true},
    {"name": "excellence", "words": 8000, "required": true},
    {"name": "impact", "words": 5000, "required": true},
    {"name": "implementation", "words": 7000, "required": true},
    {"name": "bibliography", "words": null, "required": true}
  ],
  "formatting": {"font": "Times New Roman", "font_size": 11, "margins": "15mm", "line_spacing": "single", "page_limit": 30},
  "budget": {"model": "person_months", "currency": "EUR", "indirect_rate": 0.25, "indirect_model": "flat_rate", "personnel_unit": "person-months"},
  "citation_style": "numbered",
  "review_criteria": ["excellence", "impact", "implementation"],
  "review_weights": {"excellence": 50, "impact": 30, "implementation": 20},
  "codex_agency": "msca"
}
```

Create `grant-writer-skills/templates/agencies/uefiscdi_te/agency.json`:

```json
{
  "agency": "uefiscdi",
  "mechanism": "TE",
  "name": "UEFISCDI Young Research Teams (TE)",
  "region": "romania",
  "language": ["en", "ro"],
  "sections": [
    {"name": "project_summary", "words": 500, "required": true},
    {"name": "state_of_the_art", "words": 1500, "required": true},
    {"name": "objectives", "words": 1000, "required": true},
    {"name": "methodology", "words": 2500, "required": true},
    {"name": "work_plan", "words": 800, "required": true},
    {"name": "expected_results", "words": 800, "required": true},
    {"name": "budget_justification", "words": null, "required": true},
    {"name": "bibliography", "words": null, "required": true},
    {"name": "cv_pi", "words": null, "required": true, "per_person": true}
  ],
  "formatting": {"font": "Times New Roman", "font_size": 12, "margins": "25mm", "line_spacing": "1.5"},
  "budget": {"model": "monthly_salary", "currency": "RON", "indirect_rate_cap": 0.25, "max_years": 2, "personnel_unit": "lei/month", "categories": ["personnel", "mobility", "equipment", "consumables", "indirect"]},
  "citation_style": "numbered",
  "review_criteria": ["scientific_quality", "methodology", "feasibility", "pi_capability", "impact"],
  "codex_agency": "uefiscdi"
}
```

Create `grant-writer-skills/templates/agencies/uefiscdi_pd/agency.json`:

```json
{
  "agency": "uefiscdi",
  "mechanism": "PD",
  "name": "UEFISCDI Postdoctoral Research (PD)",
  "region": "romania",
  "language": ["en", "ro"],
  "sections": [
    {"name": "project_summary", "words": 500, "required": true},
    {"name": "state_of_the_art", "words": 1500, "required": true},
    {"name": "objectives", "words": 1000, "required": true},
    {"name": "methodology", "words": 2000, "required": true},
    {"name": "work_plan", "words": 800, "required": true},
    {"name": "expected_results", "words": 800, "required": true},
    {"name": "bibliography", "words": null, "required": true},
    {"name": "cv_pi", "words": null, "required": true}
  ],
  "formatting": {"font": "Times New Roman", "font_size": 12, "margins": "25mm", "line_spacing": "1.5"},
  "budget": {"model": "monthly_salary", "currency": "RON", "indirect_rate_cap": 0.25, "max_years": 2, "personnel_unit": "lei/month"},
  "citation_style": "numbered",
  "review_criteria": ["scientific_quality", "methodology", "feasibility", "pi_capability", "impact"],
  "codex_agency": "uefiscdi"
}
```

Create `grant-writer-skills/templates/agencies/pnrr/agency.json`:

```json
{
  "agency": "pnrr",
  "mechanism": "Component 9",
  "name": "PNRR Component 9 — R&D Support",
  "region": "romania",
  "language": ["en", "ro"],
  "sections": [
    {"name": "project_summary", "words": 1000, "required": true},
    {"name": "relevance", "words": 2000, "required": true},
    {"name": "technical_description", "words": 4000, "required": true},
    {"name": "work_plan", "words": 1500, "required": true},
    {"name": "sustainability", "words": 1000, "required": true},
    {"name": "budget_justification", "words": null, "required": true},
    {"name": "bibliography", "words": null, "required": true},
    {"name": "cv_pi", "words": null, "required": true, "per_person": true}
  ],
  "formatting": {"font": "Times New Roman", "font_size": 12, "margins": "25mm", "line_spacing": "1.5"},
  "budget": {"model": "monthly_salary", "currency": "RON", "indirect_rate_cap": 0.15, "max_years": 3, "personnel_unit": "lei/month"},
  "citation_style": "numbered",
  "review_criteria": ["relevance_to_pnrr", "technical_quality", "sustainability", "budget_efficiency"],
  "codex_agency": "pnrr"
}
```

- [ ] **Step 8: Test agency_requirements.py**

```bash
cd /Users/c/lab/plugins/grant-writer-skills
python3 tools/agency_requirements.py list
python3 tools/agency_requirements.py info horizon_ria
python3 tools/agency_requirements.py sections uefiscdi_pce
python3 tools/agency_requirements.py budget erc
```

- [ ] **Step 9: Commit**

```bash
cd /Users/c/lab/plugins/grant-writer-skills
git add tools/agency_requirements.py templates/agencies/
git commit -m "feat: add agency requirements tool with 9 EU/Romanian templates"
```

---

## Task 5: Funded Grants + Budget Calculator + Compliance Checker

**Files:**
- Create: `grant-writer-skills/tools/funded_grants.py`
- Create: `grant-writer-skills/tools/budget_calculator.py`
- Create: `grant-writer-skills/tools/compliance_checker.py`

These three tools are the grant-specific utilities not found in ai-scientist-skills. Full implementations with CLI interfaces. Due to length, each file follows the patterns established in Tasks 2-4 (argparse CLI, docstrings, backoff for APIs).

- [ ] **Step 1: Write funded_grants.py**

Create `grant-writer-skills/tools/funded_grants.py` — queries OpenAIRE API for EU projects and handles UEFISCDI via WebSearch fallback. Key functions: `search_openaire(query, funding_programme, years, limit)`, `search_pi_grants(pi_name, agency)`, `format_results(projects)`. CLI: `search`, `pi-grants` subcommands. Uses `@backoff.on_exception` for retry. Returns JSON with title, PI, institution, amount, dates, abstract, programme, project_id.

- [ ] **Step 2: Write budget_calculator.py**

Create `grant-writer-skills/tools/budget_calculator.py` — supports two models: `person_months` (EU: personnel = PM * unit_cost, indirect = 25% flat of direct excl. subcontracting) and `monthly_salary` (Romania: personnel = salary * effort% * months, indirect capped at 25%). Reads `budget_input.yaml`, outputs Markdown tables. CLI: `calculate`, `format` subcommands with `--style` flag.

- [ ] **Step 3: Write compliance_checker.py**

Create `grant-writer-skills/tools/compliance_checker.py` — loads `agency.json`, counts words in each `.md` section (excluding Markdown syntax), checks required sections exist, validates figure references, checks bibliography completeness, budget caps. Returns JSON report with severity (critical/warning) per check. CLI: `check`, `word-counts`, `budget-check` subcommands.

- [ ] **Step 4: Test all three tools**

```bash
cd /Users/c/lab/plugins/grant-writer-skills
python3 tools/funded_grants.py search "machine learning" --agency horizon --limit 5
python3 tools/compliance_checker.py word-counts proposals/horizon_ria_*/
```

- [ ] **Step 5: Commit**

```bash
cd /Users/c/lab/plugins/grant-writer-skills
git add tools/funded_grants.py tools/budget_calculator.py tools/compliance_checker.py
git commit -m "feat: add funded_grants, budget_calculator, and compliance_checker tools"
```

---

## Task 6: All 15 Skills (SKILL.md files)

**Files:** 15 `SKILL.md` files in `skills/*/`

Each SKILL.md follows the ai-scientist-skills pattern: YAML frontmatter (name, description), then Markdown with Arguments, Procedure, and integration sections. The full content of each skill is specified in the design spec (Section 4, skills 4.1-4.15). Each skill references tools via `python3 tools/<module>.py` commands, invokes companion plugin skills via `/skill-name` syntax, and includes human checkpoints via AskUserQuestion where specified.

- [ ] **Step 1: Write the orchestrator skill**

Create `grant-writer-skills/skills/grant-writer/SKILL.md` — the full pipeline orchestrator. This is the largest skill (~300 lines). It implements all phases from the spec (Section 4.1): Phase 0 setup with companion detection, Phase 1 FOA analysis, Phase 1.5 landscape, Phase 2 aims, Phase 3 literature, Phase 4 preliminary data, Phase 5 proposal writing, Phase 5.5 risk analysis, Phase 6 budget, Phase 7 supporting docs, Phase 8 compliance, Phase 8.5 assembly, Phase 9 review, Phase 9.5 resubmission (if applicable), Phase 10 revision. Includes error handling section and resume logic from spec Section 4.1.

- [ ] **Step 2: Write the 14 sub-skills**

Create each SKILL.md following the spec procedures exactly:

- `skills/foa-analysis/SKILL.md` — from spec 4.2
- `skills/landscape/SKILL.md` — from spec 4.3, uses `funded_grants.py` + `/research-lookup`
- `skills/aims/SKILL.md` — from spec 4.4, iterative refinement loop
- `skills/literature/SKILL.md` — from spec 4.5, S2 + scientific-skills
- `skills/preliminary-data/SKILL.md` — from spec 4.6, vision review of figures
- `skills/proposal/SKILL.md` — from spec 4.7, section writing with templates
- `skills/risk-analysis/SKILL.md` — from spec 4.8, `/what-if-oracle` integration
- `skills/budget/SKILL.md` — from spec 4.9, `budget_calculator.py`
- `skills/supporting-docs/SKILL.md` — from spec 4.10, CVs, DMP, ethics
- `skills/compliance/SKILL.md` — from spec 4.11, `compliance_checker.py`
- `skills/review/SKILL.md` — from spec 4.12, Claude + Codex panel
- `skills/codex-review/SKILL.md` — from spec 4.13, standalone Codex
- `skills/resubmission/SKILL.md` — from spec 4.14, parse previous reviews
- `skills/revision/SKILL.md` — from spec 4.15, revision loop

- [ ] **Step 3: Commit**

```bash
cd /Users/c/lab/plugins/grant-writer-skills
git add skills/
git commit -m "feat: add all 15 skills — orchestrator + 14 sub-skills"
```

---

## Task 7: Codex Agency Calibrations (MSCA, UEFISCDI, PNRR)

**Files:**
- Modify: `/Users/c/lab/plugins/codex-plugin-cc/plugins/codex/scripts/lib/agency-calibration.mjs`

- [ ] **Step 1: Add 3 new agency calibrations**

Add MSCA, UEFISCDI, and PNRR entries to the `AGENCIES` object in `agency-calibration.mjs`, following the exact pattern of existing entries (horizon, erc, etc.). Each entry needs: `name`, `region`, `acceptanceRate`, `scoringSystem`, `keyCriteria`, `promptSection`. The calibration text for each is specified in the design spec Section 7.

- [ ] **Step 2: Update SUPPORTED_AGENCIES array**

Add `"msca"`, `"uefiscdi"`, `"pnrr"` to the exported array.

- [ ] **Step 3: Verify**

```bash
cd /Users/c/lab/plugins/codex-plugin-cc
node -e "const {SUPPORTED_AGENCIES, getAgencyCalibration} = await import('./plugins/codex/scripts/lib/agency-calibration.mjs'); console.log(SUPPORTED_AGENCIES); console.log(getAgencyCalibration('uefiscdi')?.name);"
```

Expected: Array includes msca, uefiscdi, pnrr. UEFISCDI name prints correctly.

- [ ] **Step 4: Commit**

```bash
cd /Users/c/lab/plugins/codex-plugin-cc
git add plugins/codex/scripts/lib/agency-calibration.mjs
git commit -m "feat: add MSCA, UEFISCDI, PNRR agency calibrations for grant review"
```

---

## Task 8: CLAUDE.md + README.md + Setup Script

**Files:**
- Create: `grant-writer-skills/CLAUDE.md`
- Create: `grant-writer-skills/README.md`
- Create: `grant-writer-skills/scripts/setup.py`

- [ ] **Step 1: Write CLAUDE.md**

Create `grant-writer-skills/CLAUDE.md` — project instructions for Claude Code. Follows ai-scientist-skills CLAUDE.md pattern: skills table, tool usage reference, environment requirements, agency template info, companion integration sections (scientific skills + codex).

- [ ] **Step 2: Write README.md**

Create `grant-writer-skills/README.md` — user-facing documentation. Covers: why this project, quick start (3 install options), getting started scenarios (full pipeline, aims only, review existing proposal, competitive landscape), skills reference, agency templates, companion integration, comparison with manual grant writing.

- [ ] **Step 3: Write setup.py**

Create `grant-writer-skills/scripts/setup.py` — bundled installer following ai-scientist-skills pattern. PEP 723 header, 3 modes (default/--project/--local), installs grant-writer-skills + codex-plugin-cc + claude-scientific-skills as a bundle.

- [ ] **Step 4: Commit**

```bash
cd /Users/c/lab/plugins/grant-writer-skills
git add CLAUDE.md README.md scripts/setup.py
git commit -m "feat: add CLAUDE.md, README.md, and bundled installer"
```

---

## Task 9: Examples + Final Integration Test

**Files:**
- Create: `grant-writer-skills/examples/horizon_ria_example/`
- Create: `grant-writer-skills/examples/uefiscdi_pce_example/`

- [ ] **Step 1: Create example proposal stubs**

Create example directories with sample config.yaml, a workshop description, and a sample objectives.md to demonstrate the expected directory structure and content format.

- [ ] **Step 2: Run full verification**

```bash
cd /Users/c/lab/plugins/grant-writer-skills
python3 tools/verify_setup.py
python3 tools/config.py --config templates/grant_config.yaml
python3 tools/agency_requirements.py list
python3 tools/state_manager.py init --agency uefiscdi --mechanism pce
python3 tools/state_manager.py status proposals/uefiscdi_pce_*
python3 tools/compliance_checker.py word-counts proposals/uefiscdi_pce_*/
```

- [ ] **Step 3: Final commit**

```bash
cd /Users/c/lab/plugins/grant-writer-skills
git add examples/
git commit -m "feat: add example proposals and complete integration"
```

- [ ] **Step 4: Clean up test proposals**

```bash
rm -rf /Users/c/lab/plugins/grant-writer-skills/proposals/
```
