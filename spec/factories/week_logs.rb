FactoryBot.define do
  factory :week_log do
    week_number { 1 }
    weather_roll { 1 }
    weather_effect { "MyString" }
    health_roll { 1 }
    health_effect { "MyString" }
    food_start { 1 }
    food_consumed { 1 }
    food_gathered { 1 }
    food_end { 1 }
    materials_start { 1 }
    materials_gathered { 1 }
    materials_end { 1 }
    happiness_start { 1 }
    happiness_end { 1 }
    population_start { 1 }
    population_end { 1 }
    available_workers { 1 }
    task_assignments { "" }
    notes { "MyText" }
  end
end
