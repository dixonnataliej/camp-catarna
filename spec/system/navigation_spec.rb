require 'rails_helper'

RSpec.describe "Navigation", type: :system do
  before { Town.create!(week: 2, population: 165, food: 68, materials: 71, happiness: 48) }

  it "shows the app name and nav links" do
    visit root_path

    expect(page).to have_text("Camp Catarna")
    expect(page).to have_link("Dashboard")
    expect(page).to have_link("History")
  end

  it "navigates to history from the nav" do
    visit root_path
    click_link "History"
    expect(page).to have_current_path(history_path)
  end
end
