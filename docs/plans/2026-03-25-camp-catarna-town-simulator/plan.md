---
title: Camp Catarna Town Simulator — MVP Build Plan
status: draft
created: 2026-03-25
updated: 2026-03-25
phase: 1
tags: [rails, setup, architecture, mvp, tdd, rspec, capybara]
---

# Camp Catarna Town Simulator — MVP Build Plan

A session-by-session town tracker for the players of the Usul campaign. Players log weekly dice results and task assignments; the app calculates outcomes and persists state week-over-week. The DM is not the primary user — this is a player-facing tool. The app does not auto-roll.

All features are built with **double loop TDD**: write a failing acceptance test first (outer loop), drive the implementation with failing unit tests (inner loop), and only call a step done when the acceptance test passes.

---

## Goals

1. Players can view the current state of Camp Catarna (stats, NPC statuses, active tasks)
2. Players can advance the week by entering dice results and task assignments
3. The app correctly applies all game rules (weather modifiers, health effects, food consumption, task resolution)
4. All past weeks are logged and viewable as a history
5. State persists across sessions (deployed to Render.com)

---

## Current State

| | Before | After |
|--|--------|-------|
| App | Does not exist | Rails app deployed on Render.com |
| Data | Notes/memory | Persisted in PostgreSQL (SQLite in dev) |
| Week tracking | Manual | Automated via Advance Week flow |
| NPC statuses | Notes | Tracked in `people` table with status enum |
| Session history | Notes | `week_logs` table, History page |

---

## World Context

- **World:** Usul
- **Town:** Camp Catarna — north of Viridian Lake, near Vulens, in the Hillshroud Kingdom
- **Town age:** ~15 years old
- **Starting population:** 165

---

## Game Rules Reference

### Weekly Sequence

1. Weather Roll (1d12)
2. Health Roll (1d12, modified by weather)
3. Food Consumption (−1 food per 10 population)
4. Task Assignment — distribute available population
5. Task Resolution — enter dice results, calculate outcomes

### Weather Table (1d12)

| Roll | Result | Effect |
|------|--------|--------|
| 1 | Disastrous Weather | Food only hits on 6+, lose 5% of materials, −6 Happiness |
| 2–4 | Bad Weather | −4 Happiness, −2 Food |
| 5–7 | Fine Weather | No changes |
| 8–10 | Good Weather | +2 Happiness |
| 11 | Building Weather | Buildings hit on 4+, on a 6 no material consumed, +2 Happiness |
| 12 | Harvest Time | Food hits on 4+, +2 on Health roll, +6 Happiness |

### Health Roll (1d12)

| Roll | Result | Effect |
|------|--------|--------|
| 1 | Death | −1 pop, −10 Happiness |
| 2 | Serious Illness | 1d6 people seriously sick (out until healed). −4 Happiness |
| 3 | Mild Contagious Illness | 4d6 people out this week only. −5 Happiness |
| 4 | Serious Injury | 1 person out for 3 weeks. −2 Happiness |
| 5 | Mild Illness | 1d6 people out this week |
| 6 | Mild Injury | 1 person out this week |
| 7–10 | Nothing | No effect |
| 11 | Feeling Better | 1 sick/hurt person recovers |
| 12 | Healing! | All sick/hurt people recover |

### Tasks

**Gather Food / Gather Material**
- Roll 1d6 per person assigned; hit on 5+ = +1 food or material
- 4 people guarantee a hit (8 if threshold is 6+)

**Build**
- Roll 1d6 per person; each hit = +1 progress and −1 material consumed
- Building Weather: hits on 4+, on a 6 no material consumed

**Group Task**
- Each person assigned = 1 checkmark; complete when checkmarks = total population

**Personal Task**
- Named NPCs/party members; tracked individually with notes

---

## Design

### Architecture

Standard Rails MVC with Hotwire/Turbo for the Advance Week flow. No React — Turbo Streams handle dynamic updates without a full-page reload. Tailwind for styling.

### Data Models

```ruby
# Town — singleton (one row, always id: 1)
create_table :towns do |t|
  t.integer :week, default: 1
  t.integer :population, default: 165
  t.integer :food, default: 0
  t.integer :materials, default: 0
  t.integer :happiness, default: 0
end

# People — named NPCs and party members
create_table :people do |t|
  t.string :name, null: false
  t.string :role
  t.integer :status, default: 0   # enum: active, sick, injured, out, dead
  t.integer :weeks_out, default: 0
  t.text :notes
end

# Buildings
create_table :buildings do |t|
  t.string :name, null: false
  t.integer :material_cost, null: false
  t.integer :progress, default: 0
  t.boolean :completed, default: false
  t.text :description
end

# Group Tasks
create_table :group_tasks do |t|
  t.string :name, null: false
  t.integer :checkmarks_needed, null: false
  t.integer :checkmarks_completed, default: 0
  t.boolean :completed, default: false
  t.text :effect
end

# Week Logs — one row per completed week
create_table :week_logs do |t|
  t.integer :week_number, null: false
  t.integer :weather_roll
  t.string :weather_effect
  t.integer :health_roll
  t.string :health_effect
  t.integer :food_start
  t.integer :food_consumed
  t.integer :food_gathered
  t.integer :food_end
  t.integer :materials_start
  t.integer :materials_gathered
  t.integer :materials_end
  t.integer :happiness_start
  t.integer :happiness_end
  t.integer :population_start
  t.integer :population_end
  t.integer :available_workers
  t.json :task_assignments   # { food: 80, materials: 70, personal: [...] }
  t.text :notes
end
```

### Advance Week Flow

The most complex piece. Uses a multi-step form with Turbo Frames so each step updates in place:

1. **Enter weather roll** → app shows weather effect, calculates any immediate modifiers
2. **Enter health roll** → app shows health effect, updates NPC statuses if needed
3. **Review food consumption** → app shows −N food (auto-calculated from population)
4. **Assign workers** → player enters counts per task
5. **Enter dice results** → per-task result entry (hits for food/materials, progress for buildings)
6. **Confirm & save** → app commits all changes, creates WeekLog, advances week counter

### Game Rule Encoding

Weather modifiers are stored as a constant and looked up by roll number:

```ruby
# app/models/concerns/weather_rules.rb
WEATHER_EFFECTS = {
  1  => { label: "Disastrous Weather", food_threshold: 6, material_loss_pct: 5, happiness: -6 },
  2  => { label: "Bad Weather", happiness: -4, food: -2 },
  3  => { label: "Bad Weather", happiness: -4, food: -2 },
  4  => { label: "Bad Weather", happiness: -4, food: -2 },
  5  => { label: "Fine Weather" },
  6  => { label: "Fine Weather" },
  7  => { label: "Fine Weather" },
  8  => { label: "Good Weather", happiness: 2 },
  9  => { label: "Good Weather", happiness: 2 },
  10 => { label: "Good Weather", happiness: 2 },
  11 => { label: "Building Weather", build_threshold: 4, happiness: 2 },
  12 => { label: "Harvest Time", food_threshold: 4, health_roll_bonus: 2, happiness: 6 },
}.freeze
```

---

## Build Steps

Each step follows the same pattern:
> 1. Write a failing **acceptance test** (outer loop — Capybara system spec)
> 2. Watch it fail for the right reason
> 3. Write failing **unit tests** (inner loop — model/request specs)
> 4. Implement just enough to make unit tests pass
> 5. Repeat unit test cycle until acceptance test passes
> 6. Commit

---

### Step 1: Create the Rails App

**What:** Bootstrap a new Rails 7 app with SQLite, Tailwind, and Hotwire.

```bash
rails new camp-catarna --database=sqlite3 --css=tailwind --skip-test
cd camp-catarna
```

`--skip-test` drops Minitest so we can use RSpec instead.

Verify Hotwire is included (Rails 7 ships it by default via `turbo-rails` and `stimulus-rails` in the Gemfile). Confirm:

```bash
grep -E "turbo-rails|stimulus-rails" Gemfile
```

Set up git:

```bash
git init && git add -A && git commit -m "rails new camp-catarna"
```

**No tests at this step** — this is scaffolding only.

---

### Step 2: Install Test Infrastructure

**What:** Add RSpec, Capybara, Factory Bot, and Shoulda Matchers. This is the foundation all double loop TDD depends on — get it right before writing a single model.

**Gemfile additions:**

```ruby
group :development, :test do
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "shoulda-matchers"
end
```

```bash
bundle install
rails generate rspec:install
```

This creates `spec/spec_helper.rb`, `spec/rails_helper.rb`, and `.rspec`.

**Configure `spec/rails_helper.rb`:**

```ruby
require "capybara/rails"
require "capybara/rspec"

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  # Use transactions to clean DB between tests
  config.use_transactional_fixtures = true
end

Shoulda::Matchers.configure do |config|
  config.integrate { |with| with.test_framework(:rspec).and.library(:rails) }
end
```

**Configure Capybara for system specs (`spec/support/capybara.rb`):**

```ruby
RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]
  end
end
```

Require it from `rails_helper.rb`:

```ruby
Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }
```

**Add `.rspec` flags:**

```
--require spec_helper
--format documentation
--color
```

**Smoke test — confirm RSpec runs:**

```bash
bundle exec rspec   # → 0 examples, 0 failures
```

Commit: `"Add RSpec, Capybara, Factory Bot, Shoulda Matchers"`

---

### Step 3: Models, Migrations, and Seed Data

**What:** Generate all 5 models and seed the Week 2 state.

#### 3a. Generate models

```bash
rails g model Town week:integer population:integer food:integer materials:integer happiness:integer
rails g model Person name:string role:string status:integer weeks_out:integer notes:text
rails g model Building name:string material_cost:integer progress:integer completed:boolean description:text
rails g model GroupTask name:string checkmarks_needed:integer checkmarks_completed:integer completed:boolean effect:text
rails g model WeekLog \
  week_number:integer \
  weather_roll:integer weather_effect:string \
  health_roll:integer health_effect:string \
  food_start:integer food_consumed:integer food_gathered:integer food_end:integer \
  materials_start:integer materials_gathered:integer materials_end:integer \
  happiness_start:integer happiness_end:integer \
  population_start:integer population_end:integer \
  available_workers:integer \
  task_assignments:json \
  notes:text
rails db:migrate
```

#### 3b. Inner loop — model unit tests (write first, then implement)

**`spec/models/town_spec.rb`** — write this before editing `town.rb`:

```ruby
RSpec.describe Town, type: :model do
  describe ".current" do
    it "returns the singleton row" do
      town = Town.create!(week: 3, population: 165, food: 68, materials: 71, happiness: 48)
      expect(Town.current).to eq(town)
    end
  end

  describe "#workers" do
    it "returns population minus sick and injured people" do
      Town.create!(week: 1, population: 165, food: 68, materials: 71, happiness: 48)
      create(:person, status: :sick)
      create(:person, status: :injured)
      expect(Town.current.workers).to eq(163)
    end
  end

  describe "#food_consumed_this_week" do
    it "returns floor(population / 10)" do
      town = build(:town, population: 165)
      expect(town.food_consumed_this_week).to eq(16)
    end
  end
end
```

**`spec/models/person_spec.rb`**:

```ruby
RSpec.describe Person, type: :model do
  it { should validate_presence_of(:name) }

  describe "status enum" do
    it "defaults to active" do
      person = Person.new(name: "Test")
      expect(person).to be_active
    end

    it "has all expected statuses" do
      expect(Person.statuses.keys).to match_array(%w[active sick injured out dead])
    end
  end
end
```

**`spec/factories/towns.rb`**:

```ruby
FactoryBot.define do
  factory :town do
    week { 2 }
    population { 165 }
    food { 68 }
    materials { 71 }
    happiness { 48 }
  end
end
```

**`spec/factories/people.rb`**:

```ruby
FactoryBot.define do
  factory :person do
    name { Faker::Name.first_name }
    role { "Villager" }
    status { :active }
    weeks_out { 0 }
  end
end
```

Run specs — watch them fail. Then implement:

**`app/models/town.rb`**:

```ruby
class Town < ApplicationRecord
  def self.current
    first
  end

  def workers
    population - Person.sick.count - Person.injured.count
  end

  def food_consumed_this_week
    population / 10
  end
end
```

**`app/models/person.rb`**:

```ruby
class Person < ApplicationRecord
  validates :name, presence: true
  enum status: { active: 0, sick: 1, injured: 2, out: 3, dead: 4 }
end
```

Run specs — watch them pass.

#### 3c. Seed data

**`db/seeds.rb`** — idempotent (safe to run multiple times):

```ruby
Town.find_or_create_by!(id: 1) do |t|
  t.week       = 2
  t.population = 165
  t.food       = 68
  t.materials  = 71
  t.happiness  = 48
end

{
  "Frelja"       => { role: "Mayor",                  status: :active },
  "Hanif"        => { role: "Healer",                 status: :active, notes: "Training with Gildra" },
  "Corinne"      => { role: "Fighter",                status: :active, notes: "Training with Queck" },
  "Ari"          => { role: "Kobold, caravan driver", status: :active, notes: "Training with Queck (crossbow)" },
  "Rina"         => { role: "Kobold, caravan driver", status: :active, notes: "Training with Queck (crossbow)" },
  "Anne"         => { role: "Lars' wife",             status: :out },
  "Lobo the Odd" => { role: "",                       status: :active },
}.each do |name, attrs|
  Person.find_or_create_by!(name: name) { |p| p.assign_attributes(attrs) }
end

[
  {
    week_number: 1, weather_roll: 12, weather_effect: "Harvest Time",
    health_roll: 3, health_effect: "Mild Contagious Illness (10 out)",
    food_start: 35, food_consumed: 17, food_gathered: 43, food_end: 61,
    materials_start: 20, materials_gathered: 20, materials_end: 40,
    happiness_start: 45, happiness_end: 46,
    population_start: 165, population_end: 165, available_workers: 155,
    task_assignments: { food: 80, materials: 70, personal: ["Corinne", "Ari", "Rina", "Hanif", "Frelja", "Carl"] }
  },
  {
    week_number: 2, weather_roll: 9, weather_effect: "Good Weather",
    health_roll: 11, health_effect: "Feeling Better (1 recovers)",
    food_start: 61, food_consumed: 17, food_gathered: 24, food_end: 68,
    materials_start: 40, materials_gathered: 31, materials_end: 71,
    happiness_start: 46, happiness_end: 48,
    population_start: 165, population_end: 165, available_workers: 165,
    task_assignments: { food: 59, materials: 100, personal: ["Corinne", "Ari", "Rina", "Hanif"] }
  }
].each do |attrs|
  WeekLog.find_or_create_by!(week_number: attrs[:week_number]) { |w| w.assign_attributes(attrs) }
end
```

```bash
rails db:seed
```

Verify: `rails runner "puts Town.current.inspect"` should show Week 2 state.

Commit: `"Add models, migrations, factories, seed data"`

---

### Step 4: Dashboard — First Page on Screen

**What:** A dashboard showing current week stats, NPC statuses, and active tasks. This is the first thing a player sees.

#### 4a. Outer loop — acceptance test (write first, watch fail)

**`spec/system/dashboard_spec.rb`**:

```ruby
require "rails_helper"

RSpec.describe "Dashboard", type: :system do
  before do
    Town.create!(week: 3, population: 165, food: 68, materials: 71, happiness: 48)
    create(:person, name: "Frelja", role: "Mayor", status: :active)
    create(:person, name: "Anne", role: "Lars' wife", status: :out)
  end

  it "shows the current week stats" do
    visit root_path

    expect(page).to have_text("Week 3")
    expect(page).to have_text("Food")
    expect(page).to have_text("68")
    expect(page).to have_text("Materials")
    expect(page).to have_text("71")
    expect(page).to have_text("Happiness")
    expect(page).to have_text("48")
    expect(page).to have_text("Population")
    expect(page).to have_text("165")
  end

  it "shows NPC statuses" do
    visit root_path

    expect(page).to have_text("Frelja")
    expect(page).to have_text("Active")
    expect(page).to have_text("Anne")
    expect(page).to have_text("Out")
  end
end
```

Run: `bundle exec rspec spec/system/dashboard_spec.rb` — fails with routing error. Good.

#### 4b. Inner loop — route and controller

**`config/routes.rb`**:

```ruby
Rails.application.routes.draw do
  root "dashboard#index"
end
```

Run acceptance test — fails with missing controller. Good.

**`spec/requests/dashboard_spec.rb`** — request spec:

```ruby
RSpec.describe "Dashboard", type: :request do
  it "returns 200" do
    Town.create!(week: 2, population: 165, food: 68, materials: 71, happiness: 48)
    get root_path
    expect(response).to have_http_status(:ok)
  end
end
```

Run — fails. Implement:

**`app/controllers/dashboard_controller.rb`**:

```ruby
class DashboardController < ApplicationController
  def index
    @town   = Town.current
    @people = Person.order(:name)
  end
end
```

Run request spec — passes. Run acceptance test — fails with missing template. Good.

#### 4c. Inner loop — view

**`app/views/dashboard/index.html.erb`**:

```erb
<div class="max-w-4xl mx-auto p-6">
  <h1 class="text-2xl font-bold mb-6">Camp Catarna — Week <%= @town.week %></h1>

  <!-- Stat cards -->
  <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
    <% [
      ["Food",       @town.food],
      ["Materials",  @town.materials],
      ["Happiness",  @town.happiness],
      ["Population", @town.population],
    ].each do |label, value| %>
      <div class="bg-white border rounded-lg p-4 text-center shadow-sm">
        <div class="text-sm text-gray-500 uppercase tracking-wide"><%= label %></div>
        <div class="text-3xl font-bold mt-1"><%= value %></div>
      </div>
    <% end %>
  </div>

  <!-- NPC table -->
  <h2 class="text-xl font-semibold mb-3">NPCs</h2>
  <table class="w-full text-left border-collapse">
    <thead>
      <tr class="border-b">
        <th class="py-2 pr-4">Name</th>
        <th class="py-2 pr-4">Role</th>
        <th class="py-2">Status</th>
      </tr>
    </thead>
    <tbody>
      <% @people.each do |person| %>
        <tr class="border-b last:border-0">
          <td class="py-2 pr-4 font-medium"><%= person.name %></td>
          <td class="py-2 pr-4 text-gray-600"><%= person.role %></td>
          <td class="py-2">
            <span class="px-2 py-0.5 rounded text-sm
              <%= person.active? ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800' %>">
              <%= person.status.humanize.capitalize %>
            </span>
          </td>
        </tr>
      <% end %>
    </tbody>
  </table>
</div>
```

Run acceptance test — passes. Run full suite:

```bash
bundle exec rspec
```

Commit: `"Dashboard: stat cards and NPC table"`

---

### Step 5: Nav Layout and Application Shell

**What:** Wrap the app in a consistent layout with a nav bar so every page feels cohesive. This is the last "getting something on screen" step before building the Advance Week flow.

#### 5a. Outer loop — acceptance test

**`spec/system/navigation_spec.rb`**:

```ruby
RSpec.describe "Navigation", type: :system do
  before { Town.create!(week: 2, population: 165, food: 68, materials: 71, happiness: 48) }

  it "shows the app name and nav links" do
    visit root_path

    expect(page).to have_text("Camp Catarna")
    expect(page).to have_link("Dashboard")
    expect(page).to have_link("History")
  end

  it "navigates to history from the nav" do
    visit root_path
    click_link "History"
    expect(page).to have_current_path(history_path)
  end
end
```

Run — fails because `history_path` doesn't exist. Good.

#### 5b. Inner loop — add history route (placeholder only)

**`config/routes.rb`**:

```ruby
Rails.application.routes.draw do
  root "dashboard#index"
  get "history", to: "history#index"
end
```

Create a stub controller so the route resolves:

**`app/controllers/history_controller.rb`**:

```ruby
class HistoryController < ApplicationController
  def index
    @week_logs = WeekLog.order(week_number: :asc)
  end
end
```

**`app/views/history/index.html.erb`** (stub):

```erb
<div class="max-w-4xl mx-auto p-6">
  <h1 class="text-2xl font-bold mb-4">History</h1>
  <p class="text-gray-500">No weeks logged yet.</p>
</div>
```

#### 5c. Inner loop — application layout

**`app/views/layouts/application.html.erb`** — replace the body section:

```erb
<!DOCTYPE html>
<html>
  <head>
    <title>Camp Catarna</title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= stylesheet_link_tag "tailwind", "inter-font", "application", data: { turbo_track: "reload" } %>
    <%= javascript_importmap_tags %>
  </head>
  <body class="bg-gray-50 min-h-screen">
    <nav class="bg-stone-800 text-white px-6 py-3 flex items-center gap-6">
      <span class="font-bold text-lg tracking-wide">Camp Catarna</span>
      <%= link_to "Dashboard", root_path, class: "text-stone-300 hover:text-white text-sm" %>
      <%= link_to "History",   history_path, class: "text-stone-300 hover:text-white text-sm" %>
    </nav>
    <main class="py-6">
      <%= yield %>
    </main>
  </body>
</html>
```

Run acceptance test — passes. Run full suite:

```bash
bundle exec rspec
```

Commit: `"Add nav layout and history stub route"`

---

### Step 6: History Page

**What:** A human-readable log of all past weeks, loaded from `WeekLog`.

Outer loop acceptance test → request spec → controller → view. Follow the same pattern as Step 4.

Key acceptance tests:
- Shows each logged week as a card
- Each card shows weather result, health result, food/materials delta, workers used
- Empty state when no weeks logged yet

---

### Step 7: Advance Week Flow

**What:** The most complex piece. Multi-step form using Turbo Frames — each step submits and returns the next frame. A `WeekResolver` service object applies all game rules.

Sub-steps:
1. `WeekResolver` service — write unit tests for all rule branches first
2. Turbo Frame multi-step form controller
3. Views for each step: weather → health → food → assign → results → confirm

Key unit tests for `WeekResolver`:
- `resolve_weather(12)` sets `food_threshold: 4` and `happiness_delta: +6`
- `resolve_weather(1)` sets `food_threshold: 6`, `material_loss_pct: 5`, `happiness_delta: −6`
- `food_consumed` returns `floor(population / 10)`
- `resolve_health(12)` marks all sick/injured people as active
- Advancing the week creates a `WeekLog` and increments `Town#week`

---

### Step 8: Deploy to Render.com

**What:** Production database (PostgreSQL), environment config, `render.yaml`.

```ruby
# Gemfile
gem "pg", group: :production
```

**`config/database.yml`** production section:

```yaml
production:
  adapter: postgresql
  url: <%= ENV["DATABASE_URL"] %>
```

**`render.yaml`**:

```yaml
services:
  - type: web
    name: camp-catarna
    runtime: ruby
    buildCommand: bundle install && bundle exec rails assets:precompile && bundle exec rails db:migrate
    startCommand: bundle exec rails server -b 0.0.0.0
    envVars:
      - key: RAILS_MASTER_KEY
        sync: false
      - key: DATABASE_URL
        fromDatabase:
          name: camp-catarna-db
          property: connectionString

databases:
  - name: camp-catarna-db
    plan: free
```

Set `RAILS_MASTER_KEY` in Render dashboard → Environment tab.

---

## File Change Summary

| File | Purpose |
|------|---------|
| `Gemfile` | Add rspec-rails, capybara, factory_bot_rails, faker, shoulda-matchers, pg |
| `spec/rails_helper.rb` | Configure RSpec with Capybara, Factory Bot, Shoulda Matchers |
| `spec/support/capybara.rb` | Headless Chrome system spec driver |
| `db/migrate/*.rb` | All 5 tables |
| `db/seeds.rb` | Week 1–2 history + NPC seed data (idempotent) |
| `app/models/town.rb` | Singleton model, `#workers`, `#food_consumed_this_week` |
| `app/models/person.rb` | Status enum, name validation |
| `app/models/week_log.rb` | Week record |
| `spec/factories/towns.rb` | Town factory |
| `spec/factories/people.rb` | Person factory |
| `app/controllers/dashboard_controller.rb` | Dashboard data |
| `app/controllers/history_controller.rb` | History log |
| `app/controllers/weeks_controller.rb` | Advance week flow |
| `app/services/week_resolver.rb` | Game rule application |
| `app/views/layouts/application.html.erb` | Nav shell |
| `app/views/dashboard/index.html.erb` | Dashboard UI |
| `app/views/weeks/new.html.erb` | Advance week multi-step form |
| `app/views/history/index.html.erb` | History page |
| `config/routes.rb` | All routes |
| `render.yaml` | Render.com deployment config |

---

## Testing

### Double Loop Summary

| Step | Acceptance Test | Unit Tests |
|------|-----------------|------------|
| Models | none (no UI yet) | `town_spec`, `person_spec` |
| Dashboard | `dashboard_spec.rb` (system) | `requests/dashboard_spec.rb` |
| Navigation | `navigation_spec.rb` (system) | routes |
| History | `history_spec.rb` (system) | `requests/history_spec.rb` |
| Advance Week | `advance_week_spec.rb` (system) | `week_resolver_spec.rb`, `requests/weeks_spec.rb` |

### Key Unit Test Cases

| Subject | Case |
|---------|------|
| `Town#workers` | population − sick count − injured count |
| `Town#food_consumed_this_week` | floor(165 / 10) = 16 |
| `Town.current` | returns the singleton row |
| `Person` | validates presence of name |
| `Person` | status enum defaults to active |
| `WeekResolver` | Harvest Time (roll 12) → food_threshold: 4, happiness: +6 |
| `WeekResolver` | Disastrous Weather (roll 1) → food_threshold: 6, material_loss_pct: 5 |
| `WeekResolver` | health roll 12 → all sick/injured become active |
| `WeekResolver` | creates WeekLog with correct deltas |
| `WeekResolver` | increments Town#week after commit |

### Manual Smoke Checklist

- [ ] `rails db:seed` is idempotent (run twice, no duplicates)
- [ ] Dashboard shows Week 2 seed state: Food 68, Materials 71, Happiness 48, Pop 165
- [ ] Anne shows as "Out" on dashboard
- [ ] History page shows Weeks 1 and 2
- [ ] Nav links work: Dashboard ↔ History
- [ ] Advancing week with roll 12 shows "Harvest Time" effect and sets food threshold to 4+

---

## Out of Scope (Phase 2)

- Buildings tracker with progress bars
- Group Tasks tracker
- Weather/health rule reference panel in the UI
- NPC status edit form
- Mobile-optimized layout
- User authentication (players share one view)
