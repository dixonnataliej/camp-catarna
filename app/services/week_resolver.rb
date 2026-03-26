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
    1  => { label: "Death",                  happiness: -10, population_delta: -1 },
    2  => { label: "Serious Illness",         happiness: -4 },
    3  => { label: "Mild Contagious Illness", happiness: -5 },
    4  => { label: "Serious Injury",          happiness: -2 },
    5  => { label: "Mild Illness" },
    6  => { label: "Mild Injury" },
    7  => { label: "Nothing" },
    8  => { label: "Nothing" },
    9  => { label: "Nothing" },
    10 => { label: "Nothing" },
    11 => { label: "Feeling Better",          recoveries: 1 },
    12 => { label: "Healing!",                recoveries: :all },
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

  # ── Weather ──────────────────────────────────────────────────────────────

  def weather_effect         = WEATHER_EFFECTS[weather_roll]
  def weather_label          = weather_effect[:label]
  def food_threshold         = weather_effect.fetch(:food_threshold, 5)
  def weather_happiness_delta = weather_effect.fetch(:happiness, 0)
  def weather_food_delta     = weather_effect.fetch(:food, 0)
  def health_roll_bonus      = weather_effect.fetch(:health_roll_bonus, 0)

  def weather_material_loss
    (town.materials * weather_effect.fetch(:material_loss_pct, 0) / 100.0).floor
  end

  # ── Health ───────────────────────────────────────────────────────────────

  def effective_health_roll  = [health_roll + health_roll_bonus, 12].min
  def health_effect          = HEALTH_EFFECTS[effective_health_roll]
  def health_label           = health_effect[:label]
  def health_happiness_delta = health_effect.fetch(:happiness, 0)
  def health_population_delta = health_effect.fetch(:population_delta, 0)

  # ── Totals ───────────────────────────────────────────────────────────────

  def food_consumed          = town.food_consumed_this_week
  def total_happiness_delta  = weather_happiness_delta + health_happiness_delta
  def new_food               = town.food - food_consumed + food_hits + weather_food_delta
  def new_materials          = town.materials - weather_material_loss + material_hits
  def new_happiness          = town.happiness + total_happiness_delta
  def new_population         = town.population + health_population_delta

  # ── Commit ───────────────────────────────────────────────────────────────

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
      Person.where(status: [ :sick, :injured ])
            .update_all(status: Person.statuses[:active], weeks_out: 0)
    when Integer
      Person.where(status: [ :sick, :injured ])
            .limit(health_effect[:recoveries])
            .update_all(status: Person.statuses[:active], weeks_out: 0)
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
        food:      food_workers,
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
