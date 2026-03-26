require 'rails_helper'

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

    it "does not subtract out or dead people" do
      Town.create!(week: 1, population: 165, food: 68, materials: 71, happiness: 48)
      create(:person, status: :out)
      create(:person, status: :dead)
      expect(Town.current.workers).to eq(165)
    end
  end

  describe "#food_consumed_this_week" do
    it "rounds up (ceiling) to account for player characters not in population" do
      town = build(:town, population: 165)
      expect(town.food_consumed_this_week).to eq(17)
    end

    it "is exact for clean multiples of 10" do
      town = build(:town, population: 100)
      expect(town.food_consumed_this_week).to eq(10)
    end
  end
end
