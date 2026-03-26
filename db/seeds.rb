# Seed state: end of Week 2
# Idempotent — safe to run multiple times.

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
