class Person < ApplicationRecord
  validates :name, presence: true

  enum :status, { active: 0, sick: 1, injured: 2, out: 3, dead: 4 }, default: :active
end
