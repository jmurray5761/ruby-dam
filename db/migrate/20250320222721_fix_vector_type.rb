class FixVectorType < ActiveRecord::Migration[8.0]
  def up
    # Drop the existing table and extension
    drop_table :images, if_exists: true
    execute "DROP EXTENSION IF EXISTS vector CASCADE"
    
    # Create the extension and table with the correct vector type
    execute "CREATE EXTENSION IF NOT EXISTS vector"
    
    create_table :images do |t|
      t.string :name, null: false
      t.text :description, null: false
      t.timestamps
    end

    # Add vector column
    execute "ALTER TABLE images ADD COLUMN embedding vector(512)"

    # Add index for vector similarity search
    execute "CREATE INDEX images_embedding_idx ON images USING ivfflat (embedding vector_cosine_ops)"
  end

  def down
    drop_table :images
    execute "DROP EXTENSION IF EXISTS vector CASCADE"
  end
end
