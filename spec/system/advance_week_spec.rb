require 'rails_helper'

RSpec.describe "Advance Week", type: :system do
  before do
    Town.create!(week: 3, population: 165, food: 68, materials: 71, happiness: 48)
  end

  it "advances the week by completing all steps" do
    visit new_week_advance_path

    # Step 1: weather
    fill_in "Weather roll (1–12)", with: "9"
    click_button "Next →"

    # Step 2: health — Good Weather shown, fill health roll
    expect(page).to have_text("Good Weather")
    fill_in "Health roll (1–12)", with: "8"
    click_button "Next →"

    # Step 3: food review — consumed shown, confirm
    expect(page).to have_text("16")
    click_button "Next →"

    # Step 4: workers
    fill_in "Food workers", with: "80"
    fill_in "Materials workers", with: "70"
    click_button "Next →"

    # Step 5: dice results — default threshold shown
    expect(page).to have_text("5+")
    fill_in "Food hits", with: "24"
    fill_in "Materials hits", with: "31"
    click_button "Next →"

    # Step 6: confirm summary
    expect(page).to have_text("Good Weather")
    click_button "Advance Week"

    # Redirected to dashboard — now on week 4
    expect(page).to have_current_path(root_path)
    expect(page).to have_text("Week 4")
    expect(page).to have_text("76") # 68 - 16 + 24
  end

  it "shows Harvest Time food threshold on the dice results step" do
    visit new_week_advance_path

    fill_in "Weather roll (1–12)", with: "12"
    click_button "Next →"

    expect(page).to have_text("Harvest Time")
    expect(page).to have_text("+2 to health roll")

    fill_in "Health roll (1–12)", with: "8"
    click_button "Next →"

    click_button "Next →" # food review

    fill_in "Food workers", with: "80"
    fill_in "Materials workers", with: "70"
    click_button "Next →"

    expect(page).to have_text("4+") # Harvest Time food threshold
  end
end
