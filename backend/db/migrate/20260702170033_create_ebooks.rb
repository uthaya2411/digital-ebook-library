class CreateEbooks < ActiveRecord::Migration[8.1]
  def change
    create_table :ebooks do |t|
      t.string :title
      t.string :author
      t.string :file_type
      t.integer :file_size
      t.string :cover_color_start
      t.string :cover_color_end

      t.timestamps
    end
  end
end
