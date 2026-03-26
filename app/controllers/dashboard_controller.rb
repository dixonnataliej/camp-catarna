class DashboardController < ApplicationController
  def index
    @town   = Town.current
    @people = Person.order(:name)
  end
end
