class CreatePeople < ActiveRecord::Migration[8.0]
  def change
    create_table :people do |t|
      t.string :name
      t.string :role
      t.integer :status
      t.integer :weeks_out
      t.text :notes

      t.timestamps
    end
  end
end
