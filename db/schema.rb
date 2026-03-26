# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_03_26_015756) do
  create_table "buildings", force: :cascade do |t|
    t.string "name"
    t.integer "material_cost"
    t.integer "progress"
    t.boolean "completed"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "group_tasks", force: :cascade do |t|
    t.string "name"
    t.integer "checkmarks_needed"
    t.integer "checkmarks_completed"
    t.boolean "completed"
    t.text "effect"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "people", force: :cascade do |t|
    t.string "name"
    t.string "role"
    t.integer "status"
    t.integer "weeks_out"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "towns", force: :cascade do |t|
    t.integer "week"
    t.integer "population"
    t.integer "food"
    t.integer "materials"
    t.integer "happiness"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "week_logs", force: :cascade do |t|
    t.integer "week_number"
    t.integer "weather_roll"
    t.string "weather_effect"
    t.integer "health_roll"
    t.string "health_effect"
    t.integer "food_start"
    t.integer "food_consumed"
    t.integer "food_gathered"
    t.integer "food_end"
    t.integer "materials_start"
    t.integer "materials_gathered"
    t.integer "materials_end"
    t.integer "happiness_start"
    t.integer "happiness_end"
    t.integer "population_start"
    t.integer "population_end"
    t.integer "available_workers"
    t.json "task_assignments"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end
end
