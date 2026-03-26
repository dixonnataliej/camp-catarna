require 'rails_helper'

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
    it "returns the correct label for each roll" do
      expect(resolver(weather_roll: 12).weather_label).to eq("Harvest Time")
      expect(resolver(weather_roll: 9).weather_label).to  eq("Good Weather")
      expect(resolver(weather_roll: 1).weather_label).to  eq("Disastrous Weather")
      expect(resolver(weather_roll: 3).weather_label).to  eq("Bad Weather")
      expect(resolver(weather_roll: 11).weather_label).to eq("Building Weather")
    end

    it "returns food_threshold 4 for Harvest Time" do
      expect(resolver(weather_roll: 12).food_threshold).to eq(4)
    end

    it "returns food_threshold 6 for Disastrous Weather" do
      expect(resolver(weather_roll: 1).food_threshold).to eq(6)
    end

    it "returns food_threshold 5 for normal weather" do
      expect(resolver(weather_roll: 9).food_threshold).to eq(5)
    end

    it "calculates material loss for Disastrous Weather (5% floored)" do
      expect(resolver(weather_roll: 1).weather_material_loss).to eq(3) # floor(71 * 0.05)
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

    it "returns happiness delta +2 for Good Weather" do
      expect(resolver(weather_roll: 9).weather_happiness_delta).to eq(2)
    end

    it "returns food delta -2 for Bad Weather" do
      expect(resolver(weather_roll: 2).weather_food_delta).to eq(-2)
    end
  end

  describe "health" do
    it "caps effective health roll at 12" do
      r = resolver(weather_roll: 12, health_roll: 12)
      expect(r.effective_health_roll).to eq(12)
    end

    it "applies Harvest Time bonus to health roll" do
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

    it "returns no population delta for normal rolls" do
      expect(resolver(health_roll: 8).health_population_delta).to eq(0)
    end

    it "returns Nothing label for rolls 7–10" do
      [7, 8, 9, 10].each do |roll|
        expect(resolver(health_roll: roll).health_label).to eq("Nothing")
      end
    end
  end

  describe "food and materials" do
    it "calculates food_consumed as ceiling(population / 10)" do
      expect(resolver.food_consumed).to eq(17) # ceil(165 / 10)
    end

    it "calculates new_food correctly" do
      # 68 - 17 + 24 + 0 (Good Weather, no food delta) = 75
      expect(resolver(food_hits: 24).new_food).to eq(75)
    end

    it "applies weather food delta for Bad Weather" do
      # 68 - 17 + 24 - 2 = 73
      expect(resolver(weather_roll: 2, food_hits: 24).new_food).to eq(73)
    end

    it "calculates new_materials correctly" do
      # 71 - 0 + 20 = 91
      expect(resolver(material_hits: 20).new_materials).to eq(91)
    end

    it "applies material loss for Disastrous Weather" do
      # 71 - 3 (floor 5%) + 20 = 88
      expect(resolver(weather_roll: 1, material_hits: 20).new_materials).to eq(88)
    end
  end

  describe "happiness" do
    it "sums weather and health happiness deltas" do
      # Good Weather +2, Nothing +0
      expect(resolver(weather_roll: 9, health_roll: 8).total_happiness_delta).to eq(2)
    end

    it "calculates new_happiness" do
      expect(resolver(weather_roll: 9, health_roll: 8).new_happiness).to eq(50) # 48 + 2
    end

    it "combines negative deltas correctly" do
      # Disastrous Weather -6, Death -10 → total -16
      expect(resolver(weather_roll: 1, health_roll: 1).total_happiness_delta).to eq(-16)
    end
  end

  describe "population" do
    it "returns town population unchanged for normal health" do
      expect(resolver(health_roll: 8).new_population).to eq(165)
    end

    it "decrements population by 1 on Death" do
      expect(resolver(health_roll: 1).new_population).to eq(164)
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
      expect(Town.current.food).to eq(75) # 68 - 17 + 24
    end

    it "updates the town materials" do
      resolver(material_hits: 20).resolve!
      expect(Town.current.materials).to eq(91)
    end

    it "updates the town happiness" do
      resolver(weather_roll: 9, health_roll: 8).resolve!
      expect(Town.current.happiness).to eq(50)
    end

    it "records the correct week number in the WeekLog" do
      resolver.resolve!
      expect(WeekLog.last.week_number).to eq(3)
    end

    it "recovers all sick and injured on health roll 12" do
      create(:person, status: :sick)
      create(:person, status: :injured)
      resolver(health_roll: 12).resolve!
      expect(Person.sick.count).to eq(0)
      expect(Person.injured.count).to eq(0)
    end

    it "recovers exactly one person on health roll 11" do
      create(:person, status: :sick)
      create(:person, status: :sick)
      resolver(health_roll: 11).resolve!
      expect(Person.sick.count).to eq(1)
    end

    it "does not recover anyone on rolls 1–10" do
      create(:person, status: :sick)
      resolver(health_roll: 8).resolve!
      expect(Person.sick.count).to eq(1)
    end
  end
end
