---
name: compound
description: Document a solved problem as a searchable solution file. Use after fixing a non-trivial bug or solving a tricky problem in Camp Catarna.
---

# Compound

After solving a non-trivial problem, capture it so the same problem never costs full price again.

## When to Use

- A fix required real investigation (not a typo or obvious syntax error)
- The root cause was non-obvious
- Future sessions would benefit from knowing this
- A game rule was misunderstood and caused a logic bug

## Process

### 1. Gather Context from the Conversation

Extract:
- **What broke** — the observable symptom or error message (exact text)
- **Why it broke** — the root cause
- **What fixed it** — the solution, with file paths and code
- **What didn't work** — failed attempts worth noting (if any)

If critical details are missing, ask before proceeding.

### 2. Write the Solution File

Create a markdown file in `docs/solutions/`:

```
docs/solutions/[short-description].md
```

Filename should be lowercase-with-hyphens, descriptive enough to find by scanning a directory listing (e.g., `weather-modifier-not-applied-to-food-roll.md`, `turbo-frame-missing-id-silent-failure.md`, `health-roll-bonus-ignored-on-harvest-week.md`).

Use this format:

```markdown
---
date: YYYY-MM-DD
tags: [relevant, searchable, terms]
severity: low | medium | high | critical
---

# [Short Problem Title]

## Symptom

[What was observed — exact error messages, unexpected behavior, or incorrect game state]

## Root Cause

[Why it happened — the technical explanation]

## Solution

[What fixed it — with code examples and file:line references]

## Prevention

[How to catch this earlier next time, or avoid it entirely]
```

### 3. Check for Patterns

After writing, scan `docs/solutions/` for similar past issues:

- If this is the 3rd+ occurrence of a pattern, note it — it may warrant a CLAUDE.md entry or a model validation
- If a related solution exists, add a "See also" link to both files

### 4. Confirm

Report what was created:

```
Documented: docs/solutions/[filename].md

Tags: [tag1, tag2]
```

## What Makes a Good Solution File

- Exact error messages (copy-paste, not paraphrased)
- Specific `file:line` references
- Code examples (before/after when applicable)
- The "why", not just the "what"
- Short — a future reader should get the answer in 30 seconds
- For game rule bugs: quote the relevant rule so it's clear what the correct behavior should be
