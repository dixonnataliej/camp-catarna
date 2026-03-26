require 'rails_helper'

RSpec.describe "Dashboard", type: :system do
  before do
    Town.create!(week: 3, population: 165, food: 68, materials: 71, happiness: 48)
    create(:person, name: "Frelja", role: "Mayor", status: :active)
    create(:person, name: "Anne", role: "Lars' wife", status: :out)
  end

  it "shows the current week stats" do
    visit root_path

    expect(page).to have_text("Week 3")
    expect(page).to have_text(/food/i)
    expect(page).to have_text("68")
    expect(page).to have_text(/materials/i)
    expect(page).to have_text("71")
    expect(page).to have_text(/happiness/i)
    expect(page).to have_text("48")
    expect(page).to have_text(/population/i)
    expect(page).to have_text("165")
  end

  it "shows NPC statuses" do
    visit root_path

    expect(page).to have_text("Frelja")
    expect(page).to have_text("Active")
    expect(page).to have_text("Anne")
    expect(page).to have_text("Out")
  end
end
