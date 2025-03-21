class AddVectorExtensionAndIndexes < ActiveRecord::Migration[7.1]
  def up
    # Enable the pgvector extension
    execute "CREATE EXTENSION IF NOT EXISTS vector;"
    
    # Convert the embedding column to vector type with proper default
    execute "ALTER TABLE images ALTER COLUMN embedding TYPE vector(512) USING embedding::vector(512);"
    execute "ALTER TABLE images ALTER COLUMN embedding SET DEFAULT '[0]'::vector(512);"
    
    # Add an index for vector similarity search
    execute "CREATE INDEX ON images USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);"
  end

  def down
    # Remove the index
    execute "DROP INDEX IF EXISTS images_embedding_idx;"
    
    # Convert the embedding column back to float array
    execute "ALTER TABLE images ALTER COLUMN embedding TYPE float[] USING embedding::float[];"
    execute "ALTER TABLE images ALTER COLUMN embedding SET DEFAULT '{}'::float[];"
    
    # Drop the extension
    execute "DROP EXTENSION IF EXISTS vector;"
  end
end
