# Design Spec: grant-writer-skills

**Date**: 2026-04-07
**Status**: Approved (revised)
**Location**: `/Users/c/lab/plugins/grant-writer-skills/`

---

## 1. Overview

A Claude Code plugin that orchestrates the full grant proposal lifecycle — from funding opportunity analysis through competitive positioning, iterative writing, budget preparation, compliance checking, and multi-model peer review. Follows the same hub-and-spoke architecture as ai-scientist-skills, leveraging claude-scientific-skills (134 scientific skills) and codex-plugin-cc (agency-calibrated panel review) as optional companions.

**Scope**: Europe (Horizon Europe, ERC, MSCA) and Romania (UEFISCDI, PNRR). US agencies (NIH, NSF, DOE, DARPA) deferred to v2.

**Key design decisions:**
- **One plugin, not two** — review infrastructure exists in codex-plugin-cc, writing guidance in claude-scientific-skills
- **Markdown throughout** — no LaTeX/PDF. Both Claude and Codex read `.md` files natively. Final Word/PDF conversion via existing `/docx` or `/pdf` skills at submission time
- **Human-in-the-loop** — grant writing is collaborative, not autonomous. 7+ approval checkpoints
- **Graceful degradation** — works standalone; companions enhance but aren't required
- **Bundled installer** — `scripts/setup.py` installs all 3 plugins together (Option A)
- **EU budget model** — person-months with unit costs, not US salary+fringe

## 2. Pipeline

```
 0.   Setup              →  environment, companions, agency config
 1.   FOA Analysis       →  parse funding opportunity, extract requirements
 1.5  Competitive        →  funded grants DB + literature + market analysis
      Landscape
 2.   Aims Generation    →  specific aims / objectives with iterative refinement loop
 3.   Literature         →  systematic search, gap identification, citations
 4.   Preliminary Data   →  assess PI's existing evidence
 5.   Proposal Writing   →  project summary first, then agency-specific sections
 5.5  Risk & Feasibility →  What-If-Oracle scenarios + risk matrix
 6.   Budget             →  person-months, equipment, travel, subcontracts
 7.   Supporting Docs    →  CVs, facilities, DMP, ethics, consortium agreement
 8.   Compliance         →  word counts, required sections, structure validation
 8.5  Assembly           →  compile all sections into final/proposal.md
 9.   Review             →  Claude review + Codex panel (agency-calibrated)
 9.5  Resubmission       →  parse previous reviews, plan revisions (if applicable)
10.   Revision           →  address weaknesses, re-assemble, re-review (up to 2 cycles)
```

**Human checkpoints** (uses AskUserQuestion):

| After Phase | What PI Reviews |
|-------------|----------------|
| 1. FOA Analysis | Extracted requirements, eligibility confirmation |
| 2. Aims / Objectives | Each refinement round |
| 4. Preliminary Data | Which datasets/figures to include |
| 5. Proposal sections | Draft of each major section |
| 6. Budget | Line items, person-months, justification |
| 7. Supporting Docs | CV accuracy, facilities description |
| 9. Review Results | Scores, weaknesses, revision plan |

## 3. Supported Agencies (7 templates)

### EU Agencies

| Agency | Mechanism | Template Dir | Codex Agency Key | Status |
|--------|-----------|-------------|-----------------|--------|
| Horizon Europe | RIA (Research & Innovation Action) | `horizon_ria/` | `horizon` | Existing calibration |
| Horizon Europe | IA (Innovation Action) | `horizon_ia/` | `horizon` | Existing calibration |
| ERC | Starting / Consolidator / Advanced | `erc/` | `erc` | Existing calibration |
| MSCA | Postdoctoral Fellowships | `msca_postdoc/` | `msca` | **New calibration needed** |
| MSCA | Doctoral Networks | `msca_doctoral/` | `msca` | **New calibration needed** |

### Romania

| Agency | Mechanism | Template Dir | Codex Agency Key | Status |
|--------|-----------|-------------|-----------------|--------|
| UEFISCDI | PCE (Exploratory Research) | `uefiscdi_pce/` | `uefiscdi` | **New calibration needed** |
| UEFISCDI | TE (Young Research Teams) | `uefiscdi_te/` | `uefiscdi` | **New calibration needed** |
| UEFISCDI | PD (Postdoctoral Research) | `uefiscdi_pd/` | `uefiscdi` | **New calibration needed** |
| PNRR | Component 9 (R&D Support) | `pnrr/` | `pnrr` | **New calibration needed** |

### Romanian template language support

All Romanian templates support `--lang ro|en`:
- `--lang en` (default): All sections in English
- `--lang ro`: Romanian section headers and boilerplate, English scientific content

### Agency manifest format (agency.json)

Each template directory contains an `agency.json`:

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
    {"name": "budget_justification", "words": null, "required": true},
    {"name": "bibliography", "words": null, "required": true},
    {"name": "cv_pi", "words": null, "required": true, "per_person": true}
  ],
  "formatting": {
    "font": "Times New Roman",
    "font_size": 12,
    "line_spacing": "1.5"
  },
  "budget": {
    "model": "monthly_salary",
    "currency": "RON",
    "indirect_rate_cap": 0.25,
    "max_per_year": null,
    "max_total": null,
    "max_years": 3,
    "personnel_unit": "lei/month"
  },
  "citation_style": "numbered",
  "review_criteria": ["scientific_quality", "methodology", "feasibility", "pi_capability", "impact"],
  "codex_agency": "uefiscdi"
}
```

EU agency budget example (Horizon Europe):

```json
{
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
  "citation_style": "numbered"
}
```

## 4. Skills (15)

### 4.1 `/grant-writer` — Full Pipeline Orchestrator

**Purpose**: Orchestrates all sub-skills through the pipeline.

**Arguments**:
- `--foa <path>`: Path to FOA/RFP document (PDF or URL)
- `--agency <name>`: Agency key (horizon, erc, msca, uefiscdi, pnrr)
- `--mechanism <name>`: Mechanism type (ria, ia, starting, consolidator, advanced, postdoc, doctoral, pce, te, pd)
- `--config <path>`: Config YAML (default: `templates/grant_config.yaml`)
- `--proposal-dir <path>`: Resume from existing proposal directory
- `--lang <en|ro>`: Language for Romanian templates (default: en)
- `--skip-review`: Skip review phase
- `--use-codex` / `--no-codex`: Force enable/disable Codex
- `--no-scientific-skills`: Disable claude-scientific-skills

**Phase 0 behavior**: Same detection pattern as ai-scientist-skills — check for companions via plugin.json identity (not heuristic path matching), respect config toggles, print status.

**Resume logic**: Read `state.json`, find first phase with `status != "complete"`, skip all complete phases, resume from that phase. For partially-complete phases (e.g., `proposal_writing` with `sections_done: ["project_summary", "significance"]`), resume writing from the next unfinished section.

**Error handling**:
- **FOA parsing fails** (unreadable PDF) → ask user to provide requirements manually via AskUserQuestion
- **Funded grants API down** → skip landscape phase, warn user, continue with literature-only
- **Aims loop stalls** (max rounds reached, PI not satisfied) → save progress, allow manual editing of `sections/specific_aims.md`
- **Budget calculation error** → present raw numbers from PI input, let PI verify and correct
- **Codex review timeout** → skip Codex review, Claude review is sufficient on its own
- **Compliance fails** → list all violations, do NOT proceed to assembly/review until ALL critical violations are fixed. Non-critical warnings may proceed.
- **Scientific-skills unavailable** → skip enhanced features silently, use S2 + WebSearch for literature

**Assembly logic** (Phase 8.5):
1. Read section order from `agency.json`
2. Concatenate sections with proper Markdown headers (# for top-level, ## for sub-sections)
3. Prepend project summary
4. Insert figures with proper Markdown references
5. Append bibliography
6. Validate total word count of assembled document against agency limits
7. Save to `final/proposal.md`

**Final report**: After all phases complete, print summary including:
- Proposal path: `final/proposal.md`
- Total word count and section breakdown
- Review scores (Claude + Codex if available)
- Compliance status
- Export guidance: "To convert for submission: use `/docx final/proposal.md` for Word or `/pdf final/proposal.md` for PDF"

### 4.2 `/grant-writer:foa-analysis` — FOA Parser

**Purpose**: Extract structured requirements from a funding opportunity announcement.

**Arguments**:
- `--foa <path>`: Path to FOA document (PDF, HTML, or URL)
- `--agency <name>`: Agency hint (helps parsing)
- `--output <path>`: Output directory

**Procedure**:
1. Extract text from FOA (using `pdf_reader.py` for PDFs, or WebFetch for URLs)
2. Identify: eligibility criteria, page/word limits, required sections, review criteria, deadlines, budget caps, special requirements (ethics, open access, gender dimension for EU)
3. Match against known agency templates (agency.json)
4. Output structured `foa_requirements.json`
5. **Human checkpoint**: Present extracted requirements for PI confirmation

### 4.3 `/grant-writer:landscape` — Competitive Intelligence

**Purpose**: Understand who's funded, what's trending, how to differentiate.

**Arguments**:
- `--agency <name>`: Which funding database to query
- `--query <text>`: Research topic keywords
- `--pi-name <name>`: PI's name for prior support / overlap lookup
- `--proposal-dir <path>`: Proposal directory
- `--no-scientific-skills`: Skip enhanced search

**Procedure**:
1. Query funded grant databases via `funded_grants.py`:
   - OpenAIRE API (`api.openaire.eu`) for Horizon Europe/ERC/MSCA projects
   - UEFISCDI public results for Romanian grants
2. Query PI's own funded grants for overlap analysis
3. If scientific-skills available: run `/research-lookup` + `/paper-lookup` for recent publications by funded PIs
4. For translational grants: optionally run `/market-research-reports` for market context
5. Output:
   - `landscape/funded_grants.json` — raw query results
   - `landscape/competitive_brief.md` — who's funded (top 10 competing projects with PI, title, amount, dates), funding trends, common approaches, gaps, differentiation opportunities
   - `landscape/overlap_analysis.md` — explicit comparison of each of PI's active grants against proposed work, stating scientific/budgetary overlap or lack thereof (feeds into supporting docs)
   - `landscape/prior_support.md` — summary of PI's previous funded projects and results

### 4.4 `/grant-writer:aims` — Objectives / Aims Refinement

**Purpose**: Iteratively generate and refine the objectives or specific aims (the core intellectual contribution).

**Arguments**:
- `--proposal-dir <path>`: Proposal directory
- `--max-rounds <N>`: Max refinement rounds (default: 5)
- `--codex-rounds <N>`: Max Codex review rounds during aims (default: 2)

**Procedure** (iterative loop):
1. Generate initial objectives from: research question + FOA requirements + competitive landscape + literature
2. Score objectives against agency review criteria (excellence, impact, implementation for EU; scientific quality, methodology, feasibility for UEFISCDI)
3. If score < threshold: identify weakest criterion, do targeted revision
4. Optional: invoke `/codex:grant-review sections/objectives.md --agency <agency>` for quick external review
5. **Human checkpoint**: Present objectives for PI approval
6. Repeat until approved or max rounds

**Output**: `sections/objectives.md` (or `sections/specific_aims.md` for US agencies in v2)

**EU-specific**: For Horizon Europe, objectives map to Work Packages. For ERC, objectives are the scientific aims of the PI's research program.

### 4.5 `/grant-writer:literature` — Literature Review

**Purpose**: Systematic literature search and citation gathering for grant context.

**Arguments**:
- `--proposal-dir <path>`: Proposal directory
- `--max-rounds <N>`: Search rounds (default: 3)
- `--min-citations <N>`: Minimum references to gather (default: 30)
- `--no-scientific-skills`: Skip enhanced search

**Procedure**:
1. Search S2 for core references
2. If scientific-skills: `/research-lookup` for real-time preprints, `/paper-lookup` for 10 databases, `/database-lookup` for mechanistic evidence
3. Identify gap in literature that the proposal fills
4. Build `landscape/literature.md` with categorized references
5. Build `sections/bibliography.md` with formatted citations

**Citation format**: Determined by `citation_style` in `agency.json`:
- `"numbered"` (default): `[1]`, `[2]` with numbered bibliography
- `"author_year"`: `(Smith et al., 2024)` with alphabetical bibliography

### 4.6 `/grant-writer:preliminary-data` — Evidence Assessment

**Purpose**: Help PI organize and present existing preliminary data.

**Arguments**:
- `--proposal-dir <path>`: Proposal directory
- `--data-dir <path>`: Directory with PI's existing figures/data (optional)

**Procedure**:
1. **Human checkpoint**: Ask PI what preliminary data exists (publications, unpublished results, pilot data)
2. If figures provided: review with Claude vision, assess quality and relevance. Copy to `sections/figures/`
3. Evaluate: Does preliminary data support each objective? Are there gaps?
4. Draft preliminary data narrative linking evidence to objectives
5. Output: `sections/preliminary_data.md`

### 4.7 `/grant-writer:proposal` — Section Writing

**Purpose**: Write agency-specific proposal sections.

**Arguments**:
- `--proposal-dir <path>`: Proposal directory
- `--section <name>`: Write specific section (optional, writes all if omitted)
- `--no-scientific-skills`: Skip enhanced writing

**Procedure**:
1. **Write project summary/abstract FIRST** as a distinct sub-step with its own word limits
2. Load agency template sections from `agency.json`
3. For each section, load context (objectives, literature, preliminary data, landscape)
4. If scientific-skills: apply `/scientific-writing` IMRAD structure and `/citation-management` for DOI verification
5. Generate figures via `/scientific-schematics` (methodology flowcharts, Gantt charts, work package diagrams). Save to `sections/figures/`
6. Write section content respecting word limits
7. Reference figures using Markdown: `![Description](figures/filename.png)` with caption on next line
8. Use citation style from `agency.json` (`[1]` or `(Author, Year)`)
9. **Human checkpoint**: Present each major section for PI review
10. Output: `sections/<section_name>.md` for each section

**Section order** (Horizon Europe RIA example):
1. `project_summary.md` (abstract — written first, standalone)
2. `excellence.md` (objectives, methodology, ambition)
3. `impact.md` (expected outcomes, dissemination, exploitation)
4. `implementation.md` (work plan, work packages, milestones, consortium, management)

**Section order** (UEFISCDI PCE example):
1. `project_summary.md`
2. `state_of_the_art.md`
3. `objectives.md`
4. `methodology.md`
5. `work_plan.md`
6. `expected_results.md`

**Section order** (ERC example):
1. `project_summary.md`
2. `extended_synopsis.md` (5 pages — scientific proposal)
3. `scientific_proposal.md` (15 pages — detailed research plan)
4. `curriculum_vitae.md`

### 4.8 `/grant-writer:risk-analysis` — Risk & Feasibility

**Purpose**: Structured risk assessment with scenario analysis.

**Arguments**:
- `--proposal-dir <path>`: Proposal directory

**Procedure**:
1. Invoke `/what-if-oracle` in Deep Oracle mode on the research plan
2. Structure output as risk matrix (likelihood x impact) across 5 categories: technical, personnel, timeline, budget, regulatory
3. Generate mitigation strategy for each medium/high risk
4. For EU proposals: frame as "risk management" section within Implementation
5. Integrate into `sections/risk_mitigation.md`
6. Feed risk findings into the approach/implementation section (contingency plans, alternative approaches)

### 4.9 `/grant-writer:budget` — Budget Preparation

**Purpose**: Prepare budget according to agency-specific model.

**Arguments**:
- `--proposal-dir <path>`: Proposal directory

**Procedure**:
1. Load budget model from `agency.json` (`person_months` for EU, `monthly_salary` for Romania)
2. **Human checkpoint**: Collect from PI:
   - **EU (person-months model)**: person-months per work package per partner, equipment costs, travel, subcontracting, other direct costs. Indirect = 25% flat rate of direct costs (Horizon Europe).
   - **Romania (monthly salary model)**: monthly salary per team member, effort %, equipment, mobility, consumables, indirect costs (capped at 25% for UEFISCDI)
3. Calculate using `budget_calculator.py`:
   - Per-year and total costs
   - Direct vs indirect (using agency-specific model)
   - Currency handling (EUR for EU, RON for Romania)
   - Per-work-package breakdown (Horizon Europe)
4. Generate `budget/budget.md` (Markdown tables) and `budget/justification.md` (narrative)
5. **Human checkpoint**: PI reviews line items

### 4.10 `/grant-writer:supporting-docs` — Supporting Documents

**Purpose**: Generate CVs, facilities, DMP, ethics, consortium agreements.

**Arguments**:
- `--proposal-dir <path>`: Proposal directory
- `--doc <type>`: Specific document (cv, facilities, dmp, ethics, consortium, letters, overlap)

**Procedure**:
1. **Human checkpoint**: Collect PI information (publications, positions, facilities, H-index)
2. Generate agency-specific documents:
   - **EU CV** (Europass-style or ERC template) / **Romanian CV** (UEFISCDI format)
   - Facilities & Equipment description
   - Data Management Plan (H2020/Horizon Europe DMP template, or UEFISCDI requirements)
   - Ethics self-assessment (EU-specific: ethics issues table, GDPR compliance)
   - Consortium agreement outline (multi-partner Horizon Europe proposals)
   - Draft letters of support/collaboration
   - **Overlap analysis document** — generated from `landscape/overlap_analysis.md`, formatted per agency requirements
3. Output: `supporting/<doc_type>.md`

### 4.11 `/grant-writer:compliance` — Compliance Validation

**Purpose**: Validate proposal against agency requirements before assembly.

**Arguments**:
- `--proposal-dir <path>`: Proposal directory

**Procedure**:
1. Load `agency.json` requirements
2. Run `compliance_checker.py`:
   - Word count per section (vs limits from agency.json)
   - Required sections present
   - Bibliography: every citation in text has a matching reference
   - Budget within caps (if any)
   - All team members have CVs
   - Figures referenced in text exist in `sections/figures/`
   - EU-specific: ethics table present, DMP present, gender dimension addressed
3. Report: pass/fail per check with specific fix suggestions
4. **Critical violations** (missing required section, word count exceeded by >10%) block assembly
5. **Warnings** (word count close to limit, missing optional sections) allow proceeding
6. Output: `review/compliance_report.md`

### 4.12 `/grant-writer:review` — Combined Review

**Purpose**: Claude structured review + optional Codex agency-calibrated panel.

**Arguments**:
- `--proposal-dir <path>`: Proposal directory
- `--no-codex`: Skip Codex panel
- `--no-scientific-skills`: Skip evidence assessment

**Procedure**:
1. Claude reviews `final/proposal.md` against agency criteria, produces `review/claude_review.json`
2. If scientific-skills: invoke `/scientific-critical-thinking` for GRADE evidence assessment → `review/evidence_assessment.md`
3. If Codex available: invoke `/codex:grant-review final/proposal.md --docs sections/ --panel --agency <agency> --wait`
4. Save Codex output to `review/codex_review.md`
5. Merge both reviews into `review/merged_review.json` with consensus, disagreements, combined recommendation
6. **Human checkpoint**: Present scores, top strengths/weaknesses, priority actions. PI decides revision plan.

### 4.13 `/grant-writer:codex-review` — Standalone Codex Review

**Purpose**: Run Codex grant review independently (without the full pipeline).

**Arguments**:
- `--proposal <path>`: Path to proposal Markdown file
- `--agency <name>`: Agency for calibration
- `--panel / --no-panel`: Enable/disable 3-persona panel (Scientific Reviewer, Program Officer, Feasibility Assessor)
- `--docs <path>`: Additional documents folder

**Procedure**: Direct invocation of `/codex:grant-review` with appropriate flags.

### 4.14 `/grant-writer:resubmission` — Resubmission Handler

**Purpose**: Parse previous reviewer comments and plan revisions.

**Arguments**:
- `--proposal-dir <path>`: Proposal directory
- `--reviews <path>`: Path to previous evaluation summary report / reviewer feedback (PDF)

**Procedure**:
1. Extract reviewer comments from evaluation report PDF via `pdf_reader.py`
2. Parse each criticism as a structured item: `{reviewer, category, severity, quote, section_affected}`
3. Map criticisms to proposal sections
4. Generate point-by-point response plan
5. For Horizon Europe resubmission: structure response per ESR (Evaluation Summary Report) format
6. For UEFISCDI: structure response per agency resubmission requirements
7. Output: `resubmission/previous_reviews.md` + `resubmission/response.md`
8. **Human checkpoint**: PI prioritizes which criticisms to address

### 4.15 `/grant-writer:revision` — Revision Loop

**Purpose**: Address review feedback and re-review.

**Arguments**:
- `--proposal-dir <path>`: Proposal directory
- `--max-cycles <N>`: Max revision cycles (default: 2)

**Procedure**:
1. Load review findings (Claude + Codex merged review)
2. Extract actionable weaknesses, map to sections
3. Revise affected sections with feedback injected as context
4. Re-run compliance check
5. Re-assemble `final/proposal.md` (Phase 8.5 logic)
6. Re-review revised proposal
7. **Human checkpoint**: PI reviews revision before accepting
8. Repeat up to max-cycles if score still below threshold

## 5. Tools (8 Python utilities)

### 5.1 `agency_requirements.py` (~400 lines)

Database of agency rules. Loads `agency.json` manifests from templates.

**CLI**:
```bash
python3 tools/agency_requirements.py list                        # List all agencies
python3 tools/agency_requirements.py info horizon ria            # Show requirements
python3 tools/agency_requirements.py info uefiscdi pce           # Show requirements
python3 tools/agency_requirements.py sections erc starting       # Show section limits
python3 tools/agency_requirements.py budget horizon ria          # Show budget rules
python3 tools/agency_requirements.py review-criteria uefiscdi pce # Show scoring
```

### 5.2 `funded_grants.py` (~350 lines)

Queries public funding databases for competitive intelligence.

**Backends**:
- OpenAIRE API (`api.openaire.eu/search/projects`) for Horizon Europe/ERC/MSCA — proper REST with JSON, covers all EU-funded projects
- UEFISCDI public results (web scraping with WebSearch fallback)

**CLI**:
```bash
python3 tools/funded_grants.py search "spatial transcriptomics" --agency horizon --years 2022-2026 --limit 20
python3 tools/funded_grants.py search "machine learning" --agency erc --limit 10
python3 tools/funded_grants.py search "quantum computing" --agency uefiscdi --limit 10
python3 tools/funded_grants.py pi-grants "Maria Popescu" --agency horizon
```

**Output**: JSON with title, PI, institution, amount, dates, abstract excerpt, funding programme, project ID.

### 5.3 `compliance_checker.py` (~250 lines)

Validates proposal structure against agency requirements.

**Checks**:
- Word count per section (reads .md files, counts words excluding Markdown syntax, compares to agency.json limits)
- Required sections present (all sections in agency.json with `required: true`)
- Bibliography completeness (every `[N]` or `(Author, Year)` citation has a matching reference in bibliography.md)
- Budget within caps (total, per-year, indirect rate cap)
- Personnel completeness (all named team members have CVs in supporting/)
- Figure references valid (every `![...](<path>)` points to an existing file in `sections/figures/`)
- EU-specific: ethics self-assessment present, DMP present

**CLI**:
```bash
python3 tools/compliance_checker.py check <proposal_dir>
python3 tools/compliance_checker.py word-counts <proposal_dir>
python3 tools/compliance_checker.py budget-check <proposal_dir>
```

**Output**: JSON report with pass/fail per check, severity (critical/warning), specific violations, fix suggestions.

### 5.4 `budget_calculator.py` (~300 lines)

Budget arithmetic and formatting. Supports two budget models.

**Person-months model** (Horizon Europe, ERC, MSCA):
- Personnel = person-months * unit cost per person-month
- Subcontracting (separate category, excluded from indirect base)
- Other direct costs (travel, equipment, consumables)
- Indirect costs = 25% flat rate of eligible direct costs (excluding subcontracting)
- Per-work-package breakdown

**Monthly salary model** (UEFISCDI, PNRR):
- Personnel = monthly salary * effort% * months
- Mobility (travel)
- Equipment and consumables
- Indirect costs = capped at 25% of direct costs (UEFISCDI)
- Per-year breakdown

**Features**:
- Multi-year projection
- Currency support (EUR, RON)
- Per-work-package breakdown (EU)
- Indirect cost calculation per agency model
- Budget summary tables in Markdown

**CLI**:
```bash
python3 tools/budget_calculator.py calculate <budget_input.yaml>
python3 tools/budget_calculator.py format <budget_input.yaml> --style horizon_wp
python3 tools/budget_calculator.py format <budget_input.yaml> --style uefiscdi --currency RON
```

### 5.5 `state_manager.py` (~400 lines)

Grant proposal state persistence.

**State schema**:
```json
{
  "agency": "horizon",
  "mechanism": "ria",
  "language": "en",
  "current_phase": "proposal_writing",
  "phases": {
    "setup": {"status": "complete"},
    "foa_analysis": {"status": "complete", "foa_path": "..."},
    "landscape": {"status": "complete"},
    "aims": {"status": "complete", "rounds": 3, "approved": true},
    "literature": {"status": "complete", "citations": 35},
    "preliminary_data": {"status": "complete"},
    "proposal_writing": {"status": "in_progress", "sections_done": ["project_summary", "excellence"]},
    "risk_analysis": {"status": "pending"},
    "budget": {"status": "pending"},
    "supporting_docs": {"status": "pending"},
    "compliance": {"status": "pending"},
    "assembly": {"status": "pending"},
    "review": {"status": "pending"},
    "revision": {"status": "pending"}
  },
  "config": {},
  "created_at": "...",
  "updated_at": "..."
}
```

**CLI**:
```bash
python3 tools/state_manager.py init --agency horizon --mechanism ria --config <path>
python3 tools/state_manager.py status <proposal_dir>
python3 tools/state_manager.py update <proposal_dir> --phase aims --status complete
python3 tools/state_manager.py sections <proposal_dir>  # List section completion
```

### 5.6 `config.py` (~200 lines)

Configuration management. Same dataclass + YAML pattern as ai-scientist-skills.

**Config structure** (`grant_config.yaml`):
```yaml
agency: horizon
mechanism: ria
language: en

proposal:
  title: ""
  pi_name: ""
  institution: ""
  acronym: ""              # EU proposals need a project acronym

aims:
  max_refinement_rounds: 5
  score_threshold: 4       # Out of 5 (EU scale)
  codex_review_rounds: 2

literature:
  max_search_rounds: 3
  min_citations: 30

writing:
  reflection_rounds: 3

budget:
  indirect_rate: 0.25      # 25% flat rate for Horizon Europe
  currency: EUR

review:
  revision_cycles: 2
  score_threshold: 3       # Out of 5 (EU: threshold for funding)

scientific_skills:
  enabled: auto
  enhanced_literature: true
  enhanced_writing: true
  enhanced_figures: true
  enhanced_review: true

codex:
  enabled: auto
  panel_review: true
  aims_review: true
  rescue_on_stuck: true
  agency: auto              # Derived from top-level agency field
```

### 5.7 `verify_setup.py` (~100 lines)

Environment verification. Checks:
- Python 3.11+
- Required packages (requests, pyyaml, rich, pymupdf4llm/PyMuPDF)
- Claude Code CLI
- Codex CLI + plugin (optional)
- claude-scientific-skills plugin (optional)
- S2_API_KEY (optional)

**No LaTeX check** (Markdown output only).

### 5.8 `pdf_reader.py` (~100 lines)

PDF text extraction for **input only** — parsing FOAs and evaluation summary reports.

Same implementation as ai-scientist-skills (pymupdf4llm > PyMuPDF > pypdf fallback chain).

## 6. Proposal Directory Structure

```
proposal/
├── config.yaml
├── state.json
├── foa_requirements.json
│
├── landscape/
│   ├── funded_grants.json          # Raw API results
│   ├── competitive_brief.md        # Top competing projects, trends, gaps
│   ├── overlap_analysis.md         # PI's active grants vs proposed work
│   ├── prior_support.md            # PI's previous project results
│   └── literature.md               # Categorized references with gap analysis
│
├── sections/
│   ├── project_summary.md          # Written first, standalone
│   ├── objectives.md               # Core aims/objectives
│   ├── excellence.md               # Horizon Europe
│   ├── impact.md                   # Horizon Europe
│   ├── implementation.md           # Horizon Europe
│   ├── state_of_the_art.md         # UEFISCDI
│   ├── methodology.md              # UEFISCDI
│   ├── work_plan.md                # UEFISCDI
│   ├── preliminary_data.md
│   ├── risk_mitigation.md
│   ├── bibliography.md
│   └── figures/                    # All generated and PI-provided figures
│       ├── methodology_flowchart.png
│       ├── gantt_chart.png
│       └── wp_diagram.png
│
├── budget/
│   ├── budget_input.yaml           # Raw numbers from PI
│   ├── budget.md                   # Formatted Markdown tables
│   └── justification.md            # Budget justification narrative
│
├── supporting/
│   ├── cv_pi.md                    # EU CV or UEFISCDI format
│   ├── cv_partner_1.md             # For consortium proposals
│   ├── facilities.md
│   ├── data_management.md          # DMP
│   ├── ethics_self_assessment.md   # EU-specific
│   ├── overlap.md                  # Overlap/current support document
│   └── letters/
│       └── letter_collaborator_1.md
│
├── review/
│   ├── claude_review.json
│   ├── codex_review.md
│   ├── codex_aims_review.md
│   ├── evidence_assessment.md
│   ├── merged_review.json
│   └── compliance_report.md
│
├── resubmission/                   # If applicable
│   ├── previous_reviews.md         # Parsed from ESR PDF
│   └── response.md                 # Point-by-point response
│
└── final/
    └── proposal.md                 # Assembled full proposal
```

## 7. Companion Plugin Integration

### claude-scientific-skills (existing — no changes needed)

| Phase | Skills Used |
|-------|------------|
| Landscape (1.5) | `/research-lookup`, `/paper-lookup`, `/database-lookup` |
| Landscape (1.5) | `/market-research-reports` (for translational grants) |
| Literature (3) | `/research-lookup`, `/paper-lookup`, `/database-lookup` |
| Proposal (5) | `/scientific-writing`, `/citation-management`, `/scientific-schematics` |
| Risk (5.5) | `/what-if-oracle` |
| Review (9) | `/scientific-critical-thinking` |

### codex-plugin-cc (needs 3 new agency calibrations)

| Phase | Commands Used |
|-------|-------------|
| Aims (2) | `/codex:grant-review sections/objectives.md --agency <agency>` |
| Review (9) | `/codex:grant-review final/proposal.md --panel --agency <agency> --docs sections/` |
| Stuck sections | `/codex:rescue` for fresh perspective |

**New calibrations to add to `agency-calibration.mjs`**:

1. **MSCA** (Marie Sklodowska-Curie Actions):
   - Acceptance: ~15%
   - Scoring: 0-5 per criterion, threshold 70/100 overall
   - Criteria: Excellence (50%), Impact (30%), Implementation (20%)
   - Key: Researcher's CV and career development plan heavily weighted; two-way transfer of knowledge; training-through-research

2. **UEFISCDI** (Romania):
   - Acceptance: ~20-30%
   - Scoring: 1-5 per criterion
   - Criteria: Scientific quality, Methodology, Feasibility, PI capability, Expected impact
   - Key: Preliminary data critical for credibility; international collaboration valued; publications in ISI journals weighted

3. **PNRR** (Romania National Recovery and Resilience Plan):
   - Acceptance: varies by component
   - Scoring: threshold-based with minimum per criterion
   - Criteria: Relevance to PNRR objectives, Technical quality, Sustainability, Budget efficiency
   - Key: Must align with EU Next Generation objectives; digital/green transition focus; measurable milestones required; co-financing may apply

## 8. Detection Mechanism

Plugin detection uses **plugin.json identity** (not heuristic path matching):

```bash
# Detect claude-scientific-skills
find "$HOME/.claude/plugins" ".claude/plugins" -maxdepth 5 \
  -name "plugin.json" -exec grep -l '"claude-scientific"' {} \; 2>/dev/null | head -1

# Detect codex-plugin-cc
find "$HOME/.claude/plugins" ".claude/plugins" -maxdepth 5 \
  -name "plugin.json" -exec grep -l '"codex-plugin-cc\|codex"' {} \; 2>/dev/null | head -1
```

This is more stable than ai-scientist-skills' current approach of searching for specific SKILL.md paths.

## 9. Project Structure

```
grant-writer-skills/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── .claude/
│   └── settings.json               # 15 skill registrations
├── skills/
│   ├── grant-writer/SKILL.md
│   ├── foa-analysis/SKILL.md
│   ├── landscape/SKILL.md
│   ├── aims/SKILL.md
│   ├── literature/SKILL.md
│   ├── preliminary-data/SKILL.md
│   ├── proposal/SKILL.md
│   ├── risk-analysis/SKILL.md
│   ├── budget/SKILL.md
│   ├── supporting-docs/SKILL.md
│   ├── compliance/SKILL.md
│   ├── review/SKILL.md
│   ├── codex-review/SKILL.md
│   ├── resubmission/SKILL.md
│   └── revision/SKILL.md
├── tools/
│   ├── __init__.py
│   ├── agency_requirements.py
│   ├── funded_grants.py
│   ├── compliance_checker.py
│   ├── budget_calculator.py
│   ├── state_manager.py
│   ├── config.py
│   ├── verify_setup.py
│   └── pdf_reader.py
├── templates/
│   ├── agencies/
│   │   ├── horizon_ria/
│   │   │   ├── agency.json
│   │   │   ├── project_summary.md
│   │   │   ├── excellence.md
│   │   │   ├── impact.md
│   │   │   ├── implementation.md
│   │   │   ├── cv.md
│   │   │   └── budget.md
│   │   ├── horizon_ia/
│   │   ├── erc/
│   │   ├── msca_postdoc/
│   │   ├── msca_doctoral/
│   │   ├── uefiscdi_pce/
│   │   ├── uefiscdi_te/
│   │   ├── uefiscdi_pd/
│   │   └── pnrr/
│   ├── grant_config.yaml
│   └── review_fewshot/
├── examples/
│   ├── horizon_ria_example/
│   └── uefiscdi_pce_example/
├── scripts/
│   └── setup.py                     # Bundled installer (all 3 + grant-writer)
├── CLAUDE.md
├── README.md
├── pyproject.toml
├── requirements.txt
├── LICENSE
└── .gitignore
```

## 10. Deferred to v2

- **US Agencies**: NIH (R01, R21, SBIR/STTR), NSF (Standard, CAREER, SBIR), DOE (BES, ARPA-E), DARPA (BAA)
- US budget model (salary + fringe, modular budgets, salary caps)
- NIH Other Support / NSF Current & Pending documents
- NIH A1 resubmission Introduction page
- Post-award progress reports and annual reviews
- Multi-PI collaborative grant coordination
- Letter of Intent / pre-proposal support
- Automated submission portal integration (EU Funding & Tenders Portal, UEFISCDI portal)
- Reviewer landscape intelligence
- Additional Romanian agencies (Romanian Academy, AFCN)
- Additional EU programs (EIT, COST Actions, Euratom, Digital Europe)
