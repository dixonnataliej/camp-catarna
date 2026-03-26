FactoryBot.define do
  factory :person do
    name { Faker::Name.first_name }
    role { "Villager" }
    status { :active }
    weeks_out { 0 }
    notes { nil }
  end
end
