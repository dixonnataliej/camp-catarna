class CreateTowns < ActiveRecord::Migration[8.0]
  def change
    create_table :towns do |t|
      t.integer :week
      t.integer :population
      t.integer :food
      t.integer :materials
      t.integer :happiness

      t.timestamps
    end
  end
end
