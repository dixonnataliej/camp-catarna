---
title: Steps 6 & 7 — History Page + Advance Week Flow
status: draft
created: 2026-03-25
updated: 2026-03-25
phase: 1
tags: [history, advance-week, turbo-frames, week-resolver, session, mvp]
---

# Steps 6 & 7 — History Page + Advance Week Flow

Step 6 adds a full system spec to the history page stub that already exists. Step 7 is the most complex piece of the MVP: a multi-step Advance Week form that walks players through the weekly sequence (weather → health → food → workers → dice → confirm), applies all game rules via a `WeekResolver` service, and commits the result to the database.

Both steps follow double loop TDD.

---

## Current State

| | Now | After |
|--|-----|-------|
| History page | Stub controller + view, no system spec | Full system spec, seeded data renders correctly |
| Advance Week | Nothing | Multi-step form, `WeekResolver`, WeekLog created, Town updated |
| Nav | Dashboard + History | + "Advance Week" button/link |

---

## Step 6: History Page — Full System Spec

The view (`app/views/history/index.html.erb`) already renders week cards correctly. This step is purely adding the outer loop acceptance test that locks in the expected content.

### Outer loop — `spec/system/history_spec.rb`

```ruby
RSpec.describe "History", type: :system do
  context "with no week logs" do
    before { Town.create!(week: 1, population: 165, food: 68, materials: 71, happiness: 48) }

    it "shows an empty state message" do
      visit history_path
      expect(page).to have_text("No weeks logged yet")
    end
  end

  context "with logged weeks" do
    before do
      Town.create!(week: 3, population: 165, food: 68, materials: 71, happiness: 48)
      WeekLog.create!(
        week_number: 1,
        weather_roll: 12, weather_effect: "Harvest Time",
        health_roll: 3,   health_effect: "Mild Contagious Illness (10 out)",
        food_start: 35, food_consumed: 17, food_gathered: 43, food_end: 61,
        materials_start: 20, materials_gathered: 20, materials_end: 40,
        happiness_start: 45, happiness_end: 46,
        population_start: 165, population_end: 165,
        available_workers: 155,
        task_assignments: { food: 80, materials: 70 }
      )
    end

    it "shows each week as a card with key stats" do
      visit history_path

      expect(page).to have_text("Week 1")
      expect(page).to have_text("Harvest Time")
      expect(page).to have_text("Mild Contagious Illness")
      expect(page).to have_text("35")   # food_start
      expect(page).to have_text("61")   # food_end
      expect(page).to have_text("45")   # happiness_start
      expect(page).to have_text("46")   # happiness_end
    end

    it "lists weeks in ascending order" do
      WeekLog.create!(
        week_number: 2, weather_roll: 9, weather_effect: "Good Weather",
        health_roll: 11, health_effect: "Feeling Better",
        food_start: 61, food_consumed: 17, food_gathered: 24, food_end: 68,
        materials_start: 40, materials_gathered: 31, materials_end: 71,
        happiness_start: 46, happiness_end: 48,
        population_start: 165, population_end: 165,
        available_workers: 165, task_assignments: {}
      )

      visit history_path

      week_headings = all("h2").map(&:text)
      expect(week_headings).to eq(["Week 1", "Week 2"])
    end
  end
end
```

No implementation changes needed — the existing view passes all these. This step is about locking in the behaviour with a test.

---

## Step 7: Advance Week Flow

### Overview

A multi-step form for advancing from the current week to the next. Players enter:

1. **Weather roll** (1d12) → app shows the weather effect name and any immediate modifiers
2. **Health roll** (1d12) → app shows the health effect name and description
3. **Food review** → app shows the auto-calculated food consumption, player confirms
4. **Worker assignment** → player enters how many workers go to food, materials, personal tasks
5. **Dice results** → player enters food hits and materials hits (threshold shown based on weather)
6. **Confirm** → full summary of all changes; player clicks "Advance Week" to commit

On commit: `WeekResolver` applies all rules, updates `Town`, creates `WeekLog`, redirects to dashboard showing the new week.

**MVP scope:** Buildings and Group Tasks are Phase 2. This flow only handles food gathering, materials gathering, and personal tasks (free-text notes). Build and group task resolution are excluded.

---

### State Management

State is accumulated in the Rails session (`session[:week_draft]`) across steps. Each step adds its data and renders the next step. On confirm, `WeekResolver` reads the completed draft and commits.

Session key: `session[:week_draft]`

Shape after all steps:
```ruby
{
  weather_roll: 9,
  health_roll: 11,
  food_workers: 80,
  material_workers: 70,
  personal_notes: "Frelja training, Hanif with Gildra",
  food_hits: 24,
  material_hits: 31
}
```

The session draft is cleared after a successful commit or if the player navigates away and starts again.

---

### Routes

```ruby
# config/routes.rb
resource :week_advance, only: [:new] do
  post :weather,  on: :collection
  post :health,   on: :collection
  post :food,     on: :collection
  post :workers,  on: :collection
  post :results,  on: :collection
  post :confirm,  on: :collection
end
```

Named helpers: `new_week_advance_path`, `weather_week_advance_path`, etc.

Nav link: `link_to "Advance Week", new_week_advance_path`

---

### Turbo Frame Structure

The entire multi-step form lives inside a single Turbo Frame:

```erb
<%# app/views/week_advances/new.html.erb %>
<div class="max-w-2xl mx-auto p-6">
  <h1 class="text-2xl font-bold mb-6">Advance Week</h1>

  <%= turbo_frame_tag "week-step" do %>
    <%= render "week_advances/steps/weather" %>
  <% end %>
</div>
```

Each step partial contains a form whose action points to the next step route. When submitted, the controller renders the next partial inside the same `turbo-frame` tag, replacing the current step in place.

```erb
<%# app/views/week_advances/steps/_weather.html.erb %>
<%= turbo_frame_tag "week-step" do %>
  <h2 class="text-lg font-semibold mb-4">Step 1 of 6 — Weather Roll</h2>
  <p class="text-sm text-gray-600 mb-4">Roll 1d12 and enter the result.</p>

  <%= form_with url: weather_week_advance_path, method: :post do |f| %>
    <div class="mb-4">
      <%= f.label :weather_roll, "Weather roll (1–12)", class: "block text-sm font-medium mb-1" %>
      <%= f.number_field :weather_roll, min: 1, max: 12, required: true,
            class: "border rounded px-3 py-2 w-24" %>
    </div>
    <%= f.submit "Next →", class: "bg-stone-800 text-white px-4 py-2 rounded hover:bg-stone-700" %>
  <% end %>
<% end %>
```

After the weather step submits, the controller stores the roll in the session and renders `_health.html.erb` inside the frame — which also shows the resolved weather effect:

```erb
<%# app/views/week_advances/steps/_health.html.erb %>
<%= turbo_frame_tag "week-step" do %>
  <div class="mb-4 p-3 bg-amber-50 border border-amber-200 rounded text-sm">
    <strong>Weather:</strong> <%= @weather_label %>
    <% if @weather_description.present? %>
      — <%= @weather_description %>
    <% end %>
  </div>

  <h2 class="text-lg font-semibold mb-4">Step 2 of 6 — Health Roll</h2>
  <p class="text-sm text-gray-600 mb-1">Roll 1d12.</p>
  <% if @health_roll_bonus > 0 %>
    <p class="text-sm text-green-700 mb-4">Harvest Time: +<%= @health_roll_bonus %> to your roll.</p>
  <% end %>

  <%= form_with url: health_week_advance_path, method: :post do |f| %>
    <div class="mb-4">
      <%= f.label :health_roll, "Health roll (1–12)", class: "block text-sm font-medium mb-1" %>
      <%= f.number_field :health_roll, min: 1, max: 12, required: true,
            class: "border rounded px-3 py-2 w-24" %>
    </div>
    <%= f.submit "Next →", class: "bg-stone-800 text-white px-4 py-2 rounded hover:bg-stone-700" %>
  <% end %>
<% end %>
```

All subsequent step partials follow the same pattern: show a summary of confirmed steps above, form for the current step below.

---

### WeekResolver Service

`app/services/week_resolver.rb` — pure Ruby, no ActiveRecord calls in rule logic. Receives a snapshot of the town and all player inputs, returns calculated deltas, and commits on `resolve!`.

```ruby
class WeekResolver
  WEATHER_EFFECTS = {
    1  => { label: "Disastrous Weather", food_threshold: 6, material_loss_pct: 5, happiness: -6 },
    2  => { label: "Bad Weather",        happiness: -4, food: -2 },
    3  => { label: "Bad Weather",        happiness: -4, food: -2 },
    4  => { label: "Bad Weather",        happiness: -4, food: -2 },
    5  => { label: "Fine Weather" },
    6  => { label: "Fine Weather" },
    7  => { label: "Fine Weather" },
    8  => { label: "Good Weather",       happiness: 2 },
    9  => { label: "Good Weather",       happiness: 2 },
    10 => { label: "Good Weather",       happiness: 2 },
    11 => { label: "Building Weather",   build_threshold: 4, happiness: 2 },
    12 => { label: "Harvest Time",       food_threshold: 4, health_roll_bonus: 2, happiness: 6 },
  }.freeze

  HEALTH_EFFECTS = {
    1  => { label: "Death",                     happiness: -10, population_delta: -1 },
    2  => { label: "Serious Illness",            happiness: -4 },
    3  => { label: "Mild Contagious Illness",    happiness: -5 },
    4  => { label: "Serious Injury",             happiness: -2 },
    5  => { label: "Mild Illness" },
    6  => { label: "Mild Injury" },
    7  => { label: "Nothing" },
    8  => { label: "Nothing" },
    9  => { label: "Nothing" },
    10 => { label: "Nothing" },
    11 => { label: "Feeling Better",             recoveries: 1 },
    12 => { label: "Healing!",                   recoveries: :all },
  }.freeze

  attr_reader :town, :weather_roll, :health_roll,
              :food_workers, :material_workers, :personal_notes,
              :food_hits, :material_hits

  def initialize(town:, weather_roll:, health_roll:,
                 food_workers:, material_workers:, personal_notes: nil,
                 food_hits:, material_hits:)
    @town             = town
    @weather_roll     = weather_roll.to_i
    @health_roll      = health_roll.to_i
    @food_workers     = food_workers.to_i
    @material_workers = material_workers.to_i
    @personal_notes   = personal_notes
    @food_hits        = food_hits.to_i
    @material_hits    = material_hits.to_i
  end

  # ---- Weather ----

  def weather_effect = WEATHER_EFFECTS[weather_roll]
  def weather_label  = weather_effect[:label]

  def food_threshold
    weather_effect.fetch(:food_threshold, 5)
  end

  def weather_happiness_delta
    weather_effect.fetch(:happiness, 0)
  end

  def weather_food_delta
    weather_effect.fetch(:food, 0)
  end

  def weather_material_loss
    (town.materials * weather_effect.fetch(:material_loss_pct, 0) / 100.0).floor
  end

  def health_roll_bonus
    weather_effect.fetch(:health_roll_bonus, 0)
  end

  # ---- Health ----

  def effective_health_roll
    [health_roll + health_roll_bonus, 12].min
  end

  def health_effect = HEALTH_EFFECTS[effective_health_roll]
  def health_label  = health_effect[:label]

  def health_happiness_delta
    health_effect.fetch(:happiness, 0)
  end

  def health_population_delta
    health_effect.fetch(:population_delta, 0)
  end

  # ---- Food & materials ----

  def food_consumed
    town.food_consumed_this_week
  end

  def new_food
    town.food - food_consumed + food_hits + weather_food_delta
  end

  def new_materials
    town.materials - weather_material_loss + material_hits
  end

  # ---- Happiness ----

  def total_happiness_delta
    weather_happiness_delta + health_happiness_delta
  end

  def new_happiness
    town.happiness + total_happiness_delta
  end

  # ---- Population ----

  def new_population
    town.population + health_population_delta
  end

  # ---- Commit ----

  def resolve!
    ActiveRecord::Base.transaction do
      apply_health_recoveries
      log = create_week_log
      update_town
      log
    end
  end

  private

  def apply_health_recoveries
    case health_effect[:recoveries]
    when :all
      Person.sick.update_all(status: :active, weeks_out: 0)
      Person.injured.update_all(status: :active, weeks_out: 0)
    when Integer
      people_to_recover = Person.where(status: [:sick, :injured]).limit(health_effect[:recoveries])
      people_to_recover.update_all(status: :active, weeks_out: 0)
    end
  end

  def create_week_log
    WeekLog.create!(
      week_number:        town.week,
      weather_roll:       weather_roll,
      weather_effect:     weather_label,
      health_roll:        health_roll,
      health_effect:      health_label,
      food_start:         town.food,
      food_consumed:      food_consumed,
      food_gathered:      food_hits,
      food_end:           new_food,
      materials_start:    town.materials,
      materials_gathered: material_hits,
      materials_end:      new_materials,
      happiness_start:    town.happiness,
      happiness_end:      new_happiness,
      population_start:   town.population,
      population_end:     new_population,
      available_workers:  town.workers,
      task_assignments:   {
        food:     food_workers,
        materials: material_workers,
        personal:  personal_notes
      }
    )
  end

  def update_town
    town.update!(
      food:       new_food,
      materials:  new_materials,
      happiness:  new_happiness,
      population: new_population,
      week:       town.week + 1
    )
  end
end
```

---

### Controller

```ruby
# app/controllers/week_advances_controller.rb
class WeekAdvancesController < ApplicationController
  before_action :ensure_town

  def new
    session.delete(:week_draft)
  end

  def weather
    roll = params[:weather_roll].to_i
    return redirect_to new_week_advance_path, alert: "Roll must be 1–12" unless roll.between?(1, 12)

    session[:week_draft] = { weather_roll: roll }
    @weather_label       = WeekResolver::WEATHER_EFFECTS[roll][:label]
    @health_roll_bonus   = WeekResolver::WEATHER_EFFECTS[roll].fetch(:health_roll_bonus, 0)
    @weather_description = weather_description_for(roll)
    render turbo_stream: turbo_stream.replace("week-step",
      partial: "week_advances/steps/health",
      locals: { weather_label: @weather_label,
                health_roll_bonus: @health_roll_bonus })
  end

  def health
    roll = params[:health_roll].to_i
    return redirect_to new_week_advance_path, alert: "Roll must be 1–12" unless roll.between?(1, 12)

    draft = session[:week_draft].merge(health_roll: roll)
    session[:week_draft] = draft

    bonus    = WeekResolver::WEATHER_EFFECTS[draft[:weather_roll].to_i].fetch(:health_roll_bonus, 0)
    eff_roll = [roll + bonus, 12].min
    @health_label = WeekResolver::HEALTH_EFFECTS[eff_roll][:label]
    @food_consumed = Town.current.food_consumed_this_week

    render turbo_stream: turbo_stream.replace("week-step",
      partial: "week_advances/steps/food",
      locals: { health_label: @health_label, food_consumed: @food_consumed })
  end

  def food
    session[:week_draft] = session[:week_draft].merge(food_confirmed: true)
    @town = Town.current
    render turbo_stream: turbo_stream.replace("week-step",
      partial: "week_advances/steps/workers",
      locals: { town: @town })
  end

  def workers
    draft = session[:week_draft].merge(
      food_workers:     params[:food_workers].to_i,
      material_workers: params[:material_workers].to_i,
      personal_notes:   params[:personal_notes]
    )
    session[:week_draft] = draft

    weather_roll   = draft[:weather_roll].to_i
    food_threshold = WeekResolver::WEATHER_EFFECTS[weather_roll].fetch(:food_threshold, 5)

    render turbo_stream: turbo_stream.replace("week-step",
      partial: "week_advances/steps/results",
      locals: { draft: draft, food_threshold: food_threshold })
  end

  def results
    draft = session[:week_draft].merge(
      food_hits:     params[:food_hits].to_i,
      material_hits: params[:material_hits].to_i
    )
    session[:week_draft] = draft

    @resolver = resolver_from_draft(draft)
    render turbo_stream: turbo_stream.replace("week-step",
      partial: "week_advances/steps/confirm",
      locals: { resolver: @resolver })
  end

  def confirm
    draft = session[:week_draft]
    resolver = resolver_from_draft(draft)
    resolver.resolve!
    session.delete(:week_draft)
    redirect_to root_path, notice: "Week #{Town.current.week - 1} complete!"
  end

  private

  def ensure_town
    redirect_to root_path, alert: "No town found" unless Town.current
  end

  def resolver_from_draft(draft)
    WeekResolver.new(
      town:             Town.current,
      weather_roll:     draft[:weather_roll],
      health_roll:      draft[:health_roll],
      food_workers:     draft[:food_workers],
      material_workers: draft[:material_workers],
      personal_notes:   draft[:personal_notes],
      food_hits:        draft[:food_hits],
      material_hits:    draft[:material_hits]
    )
  end

  def weather_description_for(roll)
    effect = WeekResolver::WEATHER_EFFECTS[roll]
    parts = []
    parts << "Food only hits on #{effect[:food_threshold]}+" if effect[:food_threshold]
    parts << "+#{effect[:health_roll_bonus]} to health roll" if effect[:health_roll_bonus]
    parts << "Lose #{effect[:material_loss_pct]}% materials" if effect[:material_loss_pct]
    parts << "#{effect[:happiness] > 0 ? '+' : ''}#{effect[:happiness]} Happiness" if effect[:happiness]
    parts << "#{effect[:food] > 0 ? '+' : ''}#{effect[:food]} Food" if effect[:food]
    parts << "Buildings hit on #{effect[:build_threshold]}+" if effect[:build_threshold]
    parts.join(", ")
  end
end
```

---

### Unit Tests for WeekResolver

Write these **before** creating the service file — they are the inner loop.

```ruby
# spec/services/week_resolver_spec.rb

RSpec.describe WeekResolver do
  let(:town) { build(:town, week: 3, population: 165, food: 68, materials: 71, happiness: 48) }

  def resolver(overrides = {})
    WeekResolver.new(
      town:             town,
      weather_roll:     overrides.fetch(:weather_roll, 9),
      health_roll:      overrides.fetch(:health_roll, 8),
      food_workers:     overrides.fetch(:food_workers, 80),
      material_workers: overrides.fetch(:material_workers, 70),
      personal_notes:   overrides.fetch(:personal_notes, nil),
      food_hits:        overrides.fetch(:food_hits, 24),
      material_hits:    overrides.fetch(:material_hits, 20)
    )
  end

  describe "weather" do
    it "returns the correct label" do
      expect(resolver(weather_roll: 12).weather_label).to eq("Harvest Time")
      expect(resolver(weather_roll: 9).weather_label).to eq("Good Weather")
      expect(resolver(weather_roll: 1).weather_label).to eq("Disastrous Weather")
    end

    it "returns food_threshold 4 for Harvest Time" do
      expect(resolver(weather_roll: 12).food_threshold).to eq(4)
    end

    it "returns food_threshold 6 for Disastrous Weather" do
      expect(resolver(weather_roll: 1).food_threshold).to eq(6)
    end

    it "returns default food_threshold 5 for normal weather" do
      expect(resolver(weather_roll: 9).food_threshold).to eq(5)
    end

    it "calculates material loss for Disastrous Weather" do
      # 5% of 71 = 3 (floor)
      expect(resolver(weather_roll: 1).weather_material_loss).to eq(3)
    end

    it "has no material loss for normal weather" do
      expect(resolver(weather_roll: 9).weather_material_loss).to eq(0)
    end

    it "returns health_roll_bonus 2 for Harvest Time" do
      expect(resolver(weather_roll: 12).health_roll_bonus).to eq(2)
    end

    it "returns happiness delta +6 for Harvest Time" do
      expect(resolver(weather_roll: 12).weather_happiness_delta).to eq(6)
    end

    it "returns happiness delta -6 for Disastrous Weather" do
      expect(resolver(weather_roll: 1).weather_happiness_delta).to eq(-6)
    end

    it "returns food delta -2 for Bad Weather" do
      expect(resolver(weather_roll: 2).weather_food_delta).to eq(-2)
    end
  end

  describe "health" do
    it "caps effective health roll at 12" do
      # roll 12 + bonus 2 = would be 14, caps at 12
      r = resolver(weather_roll: 12, health_roll: 12)
      expect(r.effective_health_roll).to eq(12)
    end

    it "applies Harvest Time bonus to health roll" do
      # roll 10 + bonus 2 = 12 → Healing!
      r = resolver(weather_roll: 12, health_roll: 10)
      expect(r.effective_health_roll).to eq(12)
      expect(r.health_label).to eq("Healing!")
    end

    it "returns happiness delta -10 for Death (roll 1)" do
      expect(resolver(health_roll: 1).health_happiness_delta).to eq(-10)
    end

    it "returns population delta -1 for Death" do
      expect(resolver(health_roll: 1).health_population_delta).to eq(-1)
    end

    it "returns no population delta for normal health" do
      expect(resolver(health_roll: 8).health_population_delta).to eq(0)
    end
  end

  describe "food and materials" do
    it "calculates food consumed as population / 10" do
      expect(resolver.food_consumed).to eq(16)  # 165 / 10
    end

    it "calculates new_food correctly" do
      # 68 - 16 + 24 + 0 (no weather food delta) = 76
      expect(resolver(food_hits: 24).new_food).to eq(76)
    end

    it "applies weather food delta" do
      # Bad Weather: -2 food
      # 68 - 16 + 24 - 2 = 74
      expect(resolver(weather_roll: 2, food_hits: 24).new_food).to eq(74)
    end

    it "calculates new_materials correctly" do
      # 71 - 0 (no material loss) + 20 = 91
      expect(resolver(material_hits: 20).new_materials).to eq(91)
    end

    it "applies material loss for Disastrous Weather" do
      # 71 - 3 (5% loss, floored) + 20 = 88
      expect(resolver(weather_roll: 1, material_hits: 20).new_materials).to eq(88)
    end
  end

  describe "happiness" do
    it "sums weather and health happiness deltas" do
      # Good Weather +2, Nothing +0 → total +2
      r = resolver(weather_roll: 9, health_roll: 8)
      expect(r.total_happiness_delta).to eq(2)
    end

    it "calculates new_happiness" do
      r = resolver(weather_roll: 9, health_roll: 8)
      expect(r.new_happiness).to eq(50)  # 48 + 2
    end
  end

  describe "#resolve!" do
    before { town.save! }

    it "creates a WeekLog" do
      expect { resolver.resolve! }.to change(WeekLog, :count).by(1)
    end

    it "advances the town week by 1" do
      expect { resolver.resolve! }.to change { Town.current.week }.from(3).to(4)
    end

    it "updates the town food" do
      resolver(food_hits: 24).resolve!
      expect(Town.current.food).to eq(76)  # 68 - 16 + 24
    end

    it "recovers all sick/injured on health roll 12" do
      create(:person, status: :sick)
      create(:person, status: :injured)
      resolver(health_roll: 12).resolve!
      expect(Person.sick.count).to eq(0)
      expect(Person.injured.count).to eq(0)
    end

    it "recovers one person on health roll 11" do
      create(:person, status: :sick)
      create(:person, status: :sick)
      resolver(health_roll: 11).resolve!
      expect(Person.sick.count).to eq(1)
    end

    it "records the correct week number in the WeekLog" do
      resolver.resolve!
      expect(WeekLog.last.week_number).to eq(3)
    end
  end
end
```

---

### System Spec for Advance Week

Outer loop — write before implementing the controller.

```ruby
# spec/system/advance_week_spec.rb

RSpec.describe "Advance Week", type: :system do
  before do
    Town.create!(week: 3, population: 165, food: 68, materials: 71, happiness: 48)
  end

  it "advances the week by completing all steps" do
    visit new_week_advance_path

    # Step 1: weather
    fill_in "Weather roll (1–12)", with: "9"
    click_button "Next"

    # Step 2: health — Good Weather shown
    expect(page).to have_text("Good Weather")
    fill_in "Health roll (1–12)", with: "8"
    click_button "Next"

    # Step 3: food review
    expect(page).to have_text("16")   # food consumed (165 / 10)
    click_button "Next"

    # Step 4: workers
    fill_in "Food workers",      with: "80"
    fill_in "Materials workers", with: "70"
    click_button "Next"

    # Step 5: dice results — threshold shown as 5+
    expect(page).to have_text("5+")
    fill_in "Food hits",      with: "24"
    fill_in "Materials hits", with: "31"
    click_button "Next"

    # Step 6: confirm summary
    expect(page).to have_text("Good Weather")
    expect(page).to have_text("Week 3")
    click_button "Advance Week"

    # Redirected to dashboard, now on week 4
    expect(page).to have_current_path(root_path)
    expect(page).to have_text("Week 4")
    expect(page).to have_text("76")   # 68 - 16 + 24
  end

  it "shows Harvest Time threshold on the dice results step" do
    visit new_week_advance_path

    fill_in "Weather roll (1–12)", with: "12"
    click_button "Next"

    expect(page).to have_text("Harvest Time")
    expect(page).to have_text("+2 to health roll")

    fill_in "Health roll (1–12)", with: "8"
    click_button "Next"
    click_button "Next"  # food

    fill_in "Food workers", with: "80"
    fill_in "Materials workers", with: "70"
    click_button "Next"

    expect(page).to have_text("4+")   # Harvest Time food threshold
  end
end
```

---

### File Change Summary

| File | Purpose |
|------|---------|
| `spec/system/history_spec.rb` | Step 6: acceptance tests for history page |
| `spec/services/week_resolver_spec.rb` | Step 7 inner loop: all rule branches |
| `spec/system/advance_week_spec.rb` | Step 7 outer loop: full flow end-to-end |
| `app/services/week_resolver.rb` | Game rule engine |
| `app/controllers/week_advances_controller.rb` | Multi-step form controller |
| `app/views/week_advances/new.html.erb` | Outer frame shell |
| `app/views/week_advances/steps/_weather.html.erb` | Step 1 partial |
| `app/views/week_advances/steps/_health.html.erb` | Step 2 partial |
| `app/views/week_advances/steps/_food.html.erb` | Step 3 partial |
| `app/views/week_advances/steps/_workers.html.erb` | Step 4 partial |
| `app/views/week_advances/steps/_results.html.erb` | Step 5 partial |
| `app/views/week_advances/steps/_confirm.html.erb` | Step 6 partial |
| `config/routes.rb` | `resource :week_advance` routes |
| `app/views/layouts/application.html.erb` | Add "Advance Week" nav link |

---

## Testing Checklist

### Unit tests (WeekResolver)
- [ ] All 12 weather rolls return correct label
- [ ] `food_threshold` — 4 for Harvest Time, 6 for Disastrous, 5 for everything else
- [ ] `weather_material_loss` — 5% floor for Disastrous, 0 otherwise
- [ ] `health_roll_bonus` — 2 for Harvest Time, 0 otherwise
- [ ] `effective_health_roll` caps at 12
- [ ] `health_population_delta` — -1 for Death, 0 otherwise
- [ ] `new_food` = food − consumed + hits + weather_food_delta
- [ ] `new_materials` = materials − material_loss + hits
- [ ] `resolve!` creates a WeekLog
- [ ] `resolve!` advances town week by 1
- [ ] `resolve!` with health roll 12 clears all sick/injured
- [ ] `resolve!` with health roll 11 recovers exactly one person

### Manual smoke
- [ ] Roll weather 12: "Harvest Time", "+2 to health roll" shown in step 2, "4+" shown in step 5
- [ ] Roll weather 1: "Disastrous Weather", "6+" shown in step 5
- [ ] Dashboard shows correct new week number and stats after advancing
- [ ] History page shows the newly created week log after advancing
- [ ] Visiting `/weeks/advance/new` mid-flow clears the draft and starts over

---

## Out of Scope (Phase 2)

- Building progress in worker assignment and dice results
- Group task checkmarks in worker assignment
- NPC sick/injured status auto-updates from health rolls (players do this manually)
- Validation that worker counts don't exceed available workers
- Undo / re-do a week
