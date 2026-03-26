class CreateBuildings < ActiveRecord::Migration[8.0]
  def change
    create_table :buildings do |t|
      t.string :name
      t.integer :material_cost
      t.integer :progress
      t.boolean :completed
      t.text :description

      t.timestamps
    end
  end
end
