class HistoryController < ApplicationController
  def index
    @week_logs = WeekLog.order(week_number: :asc)
  end
end
