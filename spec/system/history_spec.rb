require 'rails_helper'

RSpec.describe "History", type: :system do
  context "with no week logs" do
    before { Town.create!(week: 1, population: 165, food: 68, materials: 71, happiness: 48) }

    it "shows an empty state message" do
      visit history_path
      expect(page).to have_text("No weeks logged yet")
    end
  end

  context "with logged weeks" do
    before do
      Town.create!(week: 3, population: 165, food: 68, materials: 71, happiness: 48)
      WeekLog.create!(
        week_number: 1,
        weather_roll: 12, weather_effect: "Harvest Time",
        health_roll: 3,   health_effect: "Mild Contagious Illness (10 out)",
        food_start: 35, food_consumed: 17, food_gathered: 43, food_end: 61,
        materials_start: 20, materials_gathered: 20, materials_end: 40,
        happiness_start: 45, happiness_end: 46,
        population_start: 165, population_end: 165,
        available_workers: 155,
        task_assignments: { food: 80, materials: 70 }
      )
    end

    it "shows each week as a card with key stats" do
      visit history_path

      expect(page).to have_text("Week 1")
      expect(page).to have_text("Harvest Time")
      expect(page).to have_text("Mild Contagious Illness")
      expect(page).to have_text("35")
      expect(page).to have_text("61")
      expect(page).to have_text("45")
      expect(page).to have_text("46")
    end

    it "lists weeks in ascending order" do
      WeekLog.create!(
        week_number: 2, weather_roll: 9, weather_effect: "Good Weather",
        health_roll: 11, health_effect: "Feeling Better",
        food_start: 61, food_consumed: 17, food_gathered: 24, food_end: 68,
        materials_start: 40, materials_gathered: 31, materials_end: 71,
        happiness_start: 46, happiness_end: 48,
        population_start: 165, population_end: 165,
        available_workers: 165, task_assignments: {}
      )

      visit history_path

      week_headings = all("h2").map(&:text)
      expect(week_headings).to eq(["Week 1", "Week 2"])
    end
  end
end
