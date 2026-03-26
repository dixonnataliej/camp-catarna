FactoryBot.define do
  factory :group_task do
    name { "MyString" }
    checkmarks_needed { 1 }
    checkmarks_completed { 1 }
    completed { false }
    effect { "MyText" }
  end
end
