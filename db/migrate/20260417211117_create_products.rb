class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :name
      t.string :category
      t.text :description
      t.string :image_url

      t.timestamps
    end
  end
end
