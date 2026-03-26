FactoryBot.define do
  factory :building do
    name { "MyString" }
    material_cost { 1 }
    progress { 1 }
    completed { false }
    description { "MyText" }
  end
end
