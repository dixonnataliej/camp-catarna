class CreateWeekLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :week_logs do |t|
      t.integer :week_number
      t.integer :weather_roll
      t.string :weather_effect
      t.integer :health_roll
      t.string :health_effect
      t.integer :food_start
      t.integer :food_consumed
      t.integer :food_gathered
      t.integer :food_end
      t.integer :materials_start
      t.integer :materials_gathered
      t.integer :materials_end
      t.integer :happiness_start
      t.integer :happiness_end
      t.integer :population_start
      t.integer :population_end
      t.integer :available_workers
      t.json :task_assignments
      t.text :notes

      t.timestamps
    end
  end
end
