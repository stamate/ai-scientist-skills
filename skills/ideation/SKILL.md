---
name: ideation
description: Generate novel research ideas with literature search and novelty checking. Produces structured JSON ideas matching the AI Scientist schema.
---


# Research Ideation

You are an ambitious, creative AI/ML researcher generating novel research proposals for a top venue.

## Arguments

- `--workshop <path>`: Path to a workshop/topic description markdown file (required)
- `--num-ideas <N>`: Number of ideas to generate (default: 3)
- `--num-reflections <N>`: Reflection rounds per idea (default: 5)
- `--output <path>`: Output JSON file path (default: same dir as workshop file, `.json` extension)
- `--config <path>`: Path to config YAML for reading feature toggles (optional, defaults to `templates/bfts_config.yaml`)
- `--no-scientific-skills`: Skip enhanced multi-database literature search even if plugin is available

Parse these from the user's message.

## Procedure

### 1. Load Context

Read the workshop/topic description file. It should contain:
- Title, Keywords, TL;DR
- Abstract defining the research scope

Also check if there's an existing ideas JSON file (same path with `.json` extension). If so, load previously generated ideas to avoid duplicates.

### 2. Generate Ideas (repeat for each idea)

For each new idea (up to `num-ideas`):

#### a. Brainstorm

Think of a novel research direction within the workshop scope. Consider:
- What are open problems in this area?
- What surprising negative results or failure modes exist?
- What assumptions in current methods could be challenged?
- What cross-pollination from other fields could yield insights?

#### b. Literature Search

Before finalizing, search for related work to check novelty:
```bash
python3 tools/search.py "<your proposed topic keywords>" --limit 10 --json
```

If S2 returns no results, use the WebSearch tool to search `arxiv.org` for related papers.

Analyze the results:
- Are there papers that already address your proposed idea?
- How does your idea differ from existing work?
- What gap does your idea fill?

#### c. Reflect and Refine (repeat `num-reflections` times)

For each reflection round:
1. Consider: Is this idea truly novel given the literature?
2. Is it feasible within academic compute budgets?
3. Are the proposed experiments concrete and measurable?
4. Refine the hypothesis, experiments, and abstract.

#### d. Finalize Idea

Output a structured idea with ALL of these fields:

```json
{
  "Name": "lowercase_underscored_identifier",
  "Title": "Catchy, Informative Research Title",
  "Short Hypothesis": "Core research question or hypothesis in 1-2 sentences",
  "Related Work": "How this distinguishes from existing literature (cite specific papers found)",
  "Abstract": "~250 word conference-style abstract covering motivation, method, expected results",
  "Experiments": [
    "Experiment 1: Specific setup, dataset, metric, expected outcome",
    "Experiment 2: ...",
    "Experiment 3: ..."
  ],
  "Risk Factors and Limitations": [
    "Risk 1: Potential issue and mitigation",
    "Risk 2: ..."
  ]
}
```

### 3. Save Output

Collect all ideas into a JSON array and save to the output file:
```json
[
  { "Name": "idea_1", ... },
  { "Name": "idea_2", ... }
]
```

Also validate against the schema:
```bash
python3 -c "
import json
with open('templates/idea_schema.json') as f:
    schema = json.load(f)
# Basic validation of required fields
required = schema['required']
with open('<output_path>') as f:
    ideas = json.load(f)
for i, idea in enumerate(ideas):
    missing = [r for r in required if r not in idea]
    if missing:
        print(f'Idea {i} missing fields: {missing}')
    else:
        print(f'Idea {i} ({idea[\"Name\"]}): OK')
"
```

## Quality Criteria

Each idea should:
- Be **novel** — not a direct replication of existing work
- Be **feasible** — achievable with standard ML hardware (single GPU or Mac MPS)
- Have **clear experiments** — specific datasets, metrics, and baselines
- Target **top venue quality** — significant contribution to the field
- Include **3+ experiments** with measurable outcomes

## Enhanced Literature Search (Optional — claude-scientific-skills)

**Skip if** `--no-scientific-skills` is set, plugin not installed, or config disables it.

First, check if the claude-scientific-skills plugin is actually installed:
```bash
find "$HOME/.claude/plugins" ".claude/plugins" -maxdepth 8 -name "SKILL.md" -path "*research-lookup*" 2>/dev/null | head -1 | grep -q . && echo "SCIENTIFIC_PLUGIN_OK" || echo "SCIENTIFIC_PLUGIN_MISSING"
```
If `SCIENTIFIC_PLUGIN_MISSING`, skip this entire section silently.

Then check if the feature is enabled in the active config (use `--config` path if provided, else default):
```bash
python3 -c "
import yaml
try:
    cfg = yaml.safe_load(open('<config_path_or_templates/bfts_config.yaml>'))
    enabled = str(cfg.get('scientific_skills', {}).get('enabled', 'auto')).lower()
    lit = cfg.get('scientific_skills', {}).get('enhanced_literature', True)
    print(f'scientific_skills.enabled={enabled}')
    print(f'scientific_skills.enhanced_literature={lit}')
except: print('scientific_skills.enabled=auto\nscientific_skills.enhanced_literature=True')
" 2>/dev/null
```
Where `<config_path_or_templates/bfts_config.yaml>` is the `--config` argument if provided, otherwise `templates/bfts_config.yaml`.
If `enabled` is `false` or `enhanced_literature` is `false`, skip this section.

When enabled, augment the basic S2 literature search (step 2b) with multi-database queries for richer evidence:

1. **Real-time research** — after the S2 search, also invoke:
   ```
   /research-lookup "<topic keywords and hypothesis>"
   ```
   This uses Perplexity-powered academic search for the latest studies, preprints, and trends not yet indexed by S2.

2. **Multi-database paper search** (only if `/paper-lookup` is available — check by attempting to invoke it):
   ```
   /paper-lookup "<specific query>"
   ```
   This searches 10 databases (PubMed, arXiv, bioRxiv, OpenAlex, Crossref, Semantic Scholar, CORE, Unpaywall) for related work, citation networks, and open-access full text.
   If `/paper-lookup` is not available (e.g., using claude-scientific-writer which doesn't include it), skip this step silently.

3. **Mechanistic evidence** (only if `/database-lookup` is available, and for biology/chemistry/materials topics):
   ```
   /database-lookup "<entity name>"
   ```
   This queries 78+ databases (UniProt, STRING, Reactome, PubChem, ChEMBL, COSMIC, etc.) for mechanistic evidence that can strengthen or challenge the hypothesis.
   If `/database-lookup` is not available, skip this step silently.

Use these additional results to:
- Discover related work that S2 alone might miss (especially preprints and non-English venues)
- Find mechanistic evidence supporting or contradicting the proposed hypothesis
- Identify citation networks and key researchers in the area
- Ground the idea in real biological/chemical/physical data when applicable

The basic S2 search (step 2b) always runs first as the primary source. These enhanced searches add depth, not replace it.

## Important Notes

- Always perform at least one literature search per idea before finalizing.
- The `Name` field must be lowercase with underscores, no spaces.
- Experiments should use publicly available datasets (preferably from HuggingFace).
- Consider both positive and negative expected outcomes.
