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
