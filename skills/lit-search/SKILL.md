---
name: lit-search
description: Search academic literature using Semantic Scholar API or WebSearch. Returns papers with titles, abstracts, citation counts, and optionally bibtex entries.
---


# Literature Search

You are performing an academic literature search for the AI Scientist pipeline.

## Arguments

The user's message contains the search query. Extract it and search for relevant papers.

## Procedure

### 0. Locate Plugin Root

```bash
if [ -f "tools/verify_setup.py" ]; then AISCIENTIST_ROOT="$(pwd)"
elif [ -f "$HOME/.claude/plugins/marketplaces/ai-scientist-skills/tools/verify_setup.py" ]; then AISCIENTIST_ROOT="$HOME/.claude/plugins/marketplaces/ai-scientist-skills"
else AISCIENTIST_ROOT=$(find "$HOME/.claude/plugins" ".claude/plugins" -maxdepth 8 -name "verify_setup.py" -path "*ai-scientist*" 2>/dev/null | head -1 | xargs dirname | xargs dirname); fi
export AISCIENTIST_ROOT; echo "Plugin root: $AISCIENTIST_ROOT"
```

1. **Parse the query** from the user's message or arguments.

2. **Try Semantic Scholar first** by running:
   ```
   uv run python3 "$AISCIENTIST_ROOT/tools/search.py" "<query>" --limit 10 --json
   ```
   This uses the S2 API (with or without `S2_API_KEY`).

3. **If S2 fails or returns no results**, fall back to the WebSearch tool:
   - Search for: `"<query>" site:arxiv.org OR site:semanticscholar.org`
   - For each relevant result, extract title, authors, year, and abstract.

4. **Present results** in a clear format:
   - Numbered list with title, authors, year, venue
   - Citation count (if available)
   - Brief abstract excerpt
   - BibTeX entry (if available and requested)

5. **If the user asks for bibtex**, extract it from the S2 results or generate proper bibtex entries from the search results.

## Notes

- Prioritize papers by citation count (most cited first).
- For novelty checking, highlight papers that are closely related to the user's topic.
- If searching for a specific paper by title, use exact title in quotes.
- The `tools/search.py` script is located relative to the project root.
