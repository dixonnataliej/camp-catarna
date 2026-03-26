---
name: plan
description: Create a plan document for a Camp Catarna feature or architecture decision. Plans live in docs/plans/YYYY-MM-DD-<slug>/plan.md.
---

# Plan

Create a plan document that captures the design, rationale, and build steps for a feature or change.

## When to Use

- The user says "plan", "let's plan", "create a plan", or "I want to build..."
- A feature needs design before implementation
- An architecture decision needs documenting
- A multi-step change benefits from a written breakdown

## Process

### 1. Ask What We're Planning

Use AskUserQuestion to understand the scope:

- What feature, change, or decision are we planning?
- Is this a new feature, a refactor, an architecture decision, or something else?

If the user already described the feature in their initial message, skip to step 2.

### 2. Ask Clarifying Questions

Use AskUserQuestion with specific options based on what the user described. Ask 1–4 focused questions that surface ambiguity early. Tailor questions to the specific feature — read enough of the codebase first to ask informed questions. Examples relevant to this project:

- Is this MVP scope or Phase 2?
- Does this affect the Advance Week flow, or is it a standalone page?
- Which models are involved (Town, Person, Building, GroupTask, WeekLog)?
- Are there game rule edge cases that need encoding?

### 3. Deep Research

Research the codebase and any external resources before writing anything.

**Codebase research:**
- Read the files that will be affected
- Check `docs/plans/` for related or conflicting plans
- Check `docs/solutions/` for past problems in this area
- Understand existing patterns the plan should follow (Rails conventions, Turbo frame usage, Tailwind patterns in this app)

**External research (when relevant):**
- Rails / Hotwire / Turbo docs for any unfamiliar patterns
- Check `Gemfile` for gem versions before referencing gem APIs

Use parallel Task agents to research multiple areas at once. Do not skip this step.

### 4. Ask Informed Follow-Up Questions

After research, ask deeper questions using AskUserQuestion — things that only arise once you understand the code:

- Trade-offs between approaches you discovered
- Edge cases in the game rules that affect implementation
- Decisions that affect future extensibility (e.g., how weather modifiers get applied)

If research answered everything clearly, skip this step and tell the user what you found.

### 5. Write the Plan

Create the plan document:

```
docs/plans/YYYY-MM-DD-<slug>/plan.md
```

Use today's date. Slug should be short and descriptive (e.g., `advance-week-flow`, `npc-status-board`, `building-progress-tracker`).

#### Required frontmatter

```yaml
---
title: Human-readable plan title
status: draft
created: YYYY-MM-DD
updated: YYYY-MM-DD
phase: 1
tags: [relevant, tags]
---
```

#### Plan structure

```markdown
# [Title]

[One-paragraph summary of what this plan accomplishes and why.]

---

## Goals

[Numbered list of concrete goals — what success looks like.]

---

## Current State

[What exists today vs. what will exist after. Helps the reader understand the delta.]

---

## Design

[Core design decisions. Subsections for distinct topics. Code examples where they clarify intent. Explain *why*, not just *what*. Reference game rules where they drive implementation choices.]

---

## Build Steps

[Numbered steps with specific file paths, code examples, and clear descriptions. Each step should be independently reviewable.]

---

## File Change Summary

[Table of files changed and what changed in each.]

---

## Testing

### Unit tests
[What to test, with example cases.]

### Manual testing
[Checklist of manual verification steps — especially for game rule correctness.]

---

## Future Work (optional)

[Out-of-scope items this plan sets up for.]
```

### 6. Confirm

Report what was created:

```
Created: docs/plans/YYYY-MM-DD-<slug>/plan.md
Status: draft

Ready to implement, or revise the plan first?
```

## What Makes a Good Plan

- **Specific build steps** — an implementer can follow them without guessing
- **Code examples** — show shapes of models, controllers, Turbo frames, partials
- **File paths** — every change references the exact file
- **Game rule rationale** — explain how rules drove a design choice
- **Current state** — reader understands what exists before reading what changes
- **Scoped** — explicitly states what's out of scope (especially MVP vs Phase 2)
- **Testable** — includes concrete test cases, not just "add tests"

## What to Avoid

- Vague steps like "update the UI" or "handle edge cases"
- Assumptions about gem APIs without checking `Gemfile`
- Plans that duplicate existing functionality (check the codebase first)
- Over-engineering — plan the minimum that solves the problem
- Skipping research — every plan should be grounded in what the code actually looks like today
