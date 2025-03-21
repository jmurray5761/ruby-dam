class EnablePgvectorAndAddEmbeddingColumn < ActiveRecord::Migration[7.1]
  def up
    # Enable pgvector extension
    execute "CREATE EXTENSION IF NOT EXISTS vector"

    # Remove existing embedding column if it exists
    remove_column :images, :embedding if column_exists?(:images, :embedding)

    # Add embedding column as vector type
    execute "ALTER TABLE images ADD COLUMN embedding vector(512)"

    # Create index for similarity search
    execute "CREATE INDEX index_images_on_embedding ON images USING ivfflat (embedding vector_cosine_ops) WITH (lists = 1000)"

    # Add dimension constraint
    execute <<-SQL
      ALTER TABLE images 
      ADD CONSTRAINT check_embedding_dimensions 
      CHECK (embedding IS NULL OR vector_dims(embedding) = 512);
    SQL
  end

  def down
    # Remove constraint
    execute "ALTER TABLE images DROP CONSTRAINT check_embedding_dimensions"

    # Remove index
    execute "DROP INDEX IF EXISTS index_images_on_embedding"

    # Remove column
    remove_column :images, :embedding

    # Disable extension
    execute "DROP EXTENSION IF EXISTS vector"
  end
end
