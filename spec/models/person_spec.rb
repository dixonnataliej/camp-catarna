require 'rails_helper'

RSpec.describe Person, type: :model do
  it { should validate_presence_of(:name) }

  describe "status enum" do
    it "defaults to active" do
      person = Person.new(name: "Test")
      expect(person).to be_active
    end

    it "has all expected statuses" do
      expect(Person.statuses.keys).to match_array(%w[active sick injured out dead])
    end
  end
end
