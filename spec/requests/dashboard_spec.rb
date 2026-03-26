require 'rails_helper'

RSpec.describe "Dashboard", type: :request do
  before { Town.create!(week: 2, population: 165, food: 68, materials: 71, happiness: 48) }

  it "returns 200" do
    get root_path
    expect(response).to have_http_status(:ok)
  end

  it "exposes town stats in the response body" do
    get root_path
    expect(response.body).to include("68")  # food
    expect(response.body).to include("71")  # materials
  end
end
