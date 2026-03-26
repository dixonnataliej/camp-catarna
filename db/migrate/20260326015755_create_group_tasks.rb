class CreateGroupTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :group_tasks do |t|
      t.string :name
      t.integer :checkmarks_needed
      t.integer :checkmarks_completed
      t.boolean :completed
      t.text :effect

      t.timestamps
    end
  end
end
