class EnablePgvectorAndFixEmbeddingColumn < ActiveRecord::Migration[7.0]
  def up
    # Enable the pgvector extension
    execute 'CREATE EXTENSION IF NOT EXISTS vector'

    # Drop the existing embedding column if it exists
    remove_column :images, :embedding if column_exists?(:images, :embedding)

    # Add the embedding column with the correct vector type
    execute 'ALTER TABLE images ADD COLUMN embedding vector(512)'

    # Add an index for similarity search
    execute 'CREATE INDEX images_embedding_idx ON images USING ivfflat (embedding vector_l2_ops)'
  end

  def down
    # Remove the index
    execute 'DROP INDEX IF EXISTS images_embedding_idx'

    # Remove the embedding column
    remove_column :images, :embedding if column_exists?(:images, :embedding)

    # Disable the pgvector extension
    execute 'DROP EXTENSION IF EXISTS vector'
  end
end
