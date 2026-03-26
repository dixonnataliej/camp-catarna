class WeekAdvancesController < ApplicationController
  before_action :set_town

  def new
    session.delete(:week_draft)
    @step = :weather
  end

  def weather
    roll = params[:weather_roll].to_i
    session[:week_draft] = { "weather_roll" => roll }
    effect = WeekResolver::WEATHER_EFFECTS[roll]
    @weather_label     = effect[:label]
    @health_roll_bonus = effect.fetch(:health_roll_bonus, 0)
    @weather_summary   = weather_summary(effect)
    @step = :health
    render :new
  end

  def health
    roll  = params[:health_roll].to_i
    draft = session[:week_draft].merge("health_roll" => roll)
    session[:week_draft] = draft

    weather_effect = WeekResolver::WEATHER_EFFECTS[draft["weather_roll"].to_i]
    bonus          = weather_effect.fetch(:health_roll_bonus, 0)
    eff_roll       = [roll + bonus, 12].min
    @health_label  = WeekResolver::HEALTH_EFFECTS[eff_roll][:label]
    @food_consumed = @town.food_consumed_this_week
    @step = :food
    render :new
  end

  def food
    session[:week_draft] = session[:week_draft].merge("food_confirmed" => true)
    @step = :workers
    render :new
  end

  def workers
    draft = session[:week_draft].merge(
      "food_workers"     => params[:food_workers].to_i,
      "material_workers" => params[:material_workers].to_i,
      "personal_notes"   => params[:personal_notes]
    )
    session[:week_draft] = draft
    weather_roll    = draft["weather_roll"].to_i
    @food_threshold = WeekResolver::WEATHER_EFFECTS[weather_roll].fetch(:food_threshold, 5)
    @step = :results
    render :new
  end

  def results
    draft = session[:week_draft].merge(
      "food_hits"     => params[:food_hits].to_i,
      "material_hits" => params[:material_hits].to_i
    )
    session[:week_draft] = draft
    @resolver = build_resolver(draft)
    @step = :confirm
    render :new
  end

  def confirm
    build_resolver(session[:week_draft]).resolve!
    session.delete(:week_draft)
    redirect_to root_path, notice: "Week advanced!"
  end

  private

  def set_town
    @town = Town.current
  end

  def build_resolver(draft)
    WeekResolver.new(
      town:             @town,
      weather_roll:     draft["weather_roll"],
      health_roll:      draft["health_roll"],
      food_workers:     draft["food_workers"],
      material_workers: draft["material_workers"],
      personal_notes:   draft["personal_notes"],
      food_hits:        draft["food_hits"],
      material_hits:    draft["material_hits"]
    )
  end

  def weather_summary(effect)
    parts = []
    parts << "Food hits on #{effect[:food_threshold]}+"       if effect[:food_threshold]
    parts << "+#{effect[:health_roll_bonus]} to health roll"  if effect[:health_roll_bonus]
    parts << "Lose #{effect[:material_loss_pct]}% materials"  if effect[:material_loss_pct]
    parts << "#{effect[:happiness] >= 0 ? '+' : ''}#{effect[:happiness]} Happiness" if effect[:happiness]
    parts << "#{effect[:food] >= 0 ? '+' : ''}#{effect[:food]} Food"                if effect[:food]
    parts << "Buildings hit on #{effect[:build_threshold]}+"  if effect[:build_threshold]
    parts.join(", ")
  end
end
