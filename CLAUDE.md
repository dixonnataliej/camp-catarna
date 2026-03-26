# Camp Catarna — CLAUDE.md

## Project Overview

A session-by-session town tracker for the players of the Usul campaign. Players log weekly dice results and task assignments; the app calculates outcomes and persists state week-over-week. The DM is **not** the primary user — this is a player-facing tool.

**The app does not auto-roll.** Players enter their actual dice results.

---

## Tech Stack

| Layer | Choice |
|-------|--------|
| Framework | Ruby on Rails |
| Frontend | Hotwire / Turbo |
| Styling | Tailwind CSS |
| Database (dev) | SQLite |
| Database (prod) | PostgreSQL |
| Deployment | Render.com (not Vercel — Vercel does not support Rails well) |

---

## Key Domain Concepts

- **Town:** Camp Catarna — singleton data model, one row
- **Week:** The core unit of play. Each week: Weather Roll → Health Roll → Food Consumption → Task Assignment → Task Resolution
- **Workers:** Available population after subtracting sick/injured NPCs
- **Food consumption:** ceiling(population / 10) per week — rounds up to account for player characters not tracked in population
- **Tasks:** Gather Food, Gather Materials, Build, Group Task, Personal Task
- **Hit threshold:** Default 5+ on 1d6; modified by weather (e.g., Harvest Time drops food threshold to 4+)

---

## Data Models

- `Town` — singleton: week, population, food, materials, happiness
- `Person` — named NPCs: name, role, status (active/sick/injured/out/dead), weeks_out, notes
- `Building` — name, material_cost, progress, completed, description
- `GroupTask` — name, checkmarks_needed, checkmarks_completed, completed, effect
- `WeekLog` — full record per week including all rolls, task assignments (JSON), stat deltas

---

## Pages

| Page | Purpose |
|------|---------|
| Dashboard | Current week snapshot — stats, NPC statuses, active buildings/tasks |
| Advance Week | Step-by-step form: weather roll → health roll → assign workers → dice results → confirm |
| Buildings | List buildings with progress bars, start new build |
| Group Tasks | Track checkmark progress |
| NPCs | Status board, update status/notes |
| History | Human-readable log of all past weeks |

---

## Development Methodology

All features use **double loop TDD**:

1. Write a failing **acceptance test** first (outer loop — RSpec system spec with Capybara)
2. Watch it fail for the right reason
3. Write failing **unit tests** (inner loop — model/request specs)
4. Implement just enough to make unit tests pass
5. Repeat inner loop until the acceptance test passes
6. Commit

Never write implementation code without a failing test at the appropriate level.

**Test stack:** RSpec · Capybara (headless Chrome) · Factory Bot · Shoulda Matchers

---

## MVP Build Order

1. Rails app setup (models, migrations, seed data)
2. Dashboard
3. Advance Week flow
4. History page

Phase 2: Buildings tracker, Group Tasks tracker, rules reference panel

---

## Seed State (End of Week 2)

- Food: 68 | Materials: 71 | Happiness: 48 | Population: 165 | Week: 2
- NPCs: Frelja (active), Hanif (training/Gildra), Corinne (training/Queck), Ari (training/Queck crossbow), Rina (training/Queck crossbow), Anne (out/unknown), Lobo the Odd (active)

---

## Docs Conventions

- **Plans** live in `docs/plans/YYYY-MM-DD-<slug>/plan.md` — use the `/plan` command to create one
- **Solutions** live in `docs/solutions/<short-description>.md` — use the `/compound` command after fixing a non-trivial bug

---

## Commands

| Command | Purpose |
|---------|---------|
| `/plan` | Create a plan document for a feature or architecture decision |
| `/compound` | Document a solved problem as a searchable solution file |
