class UpdateEmbeddingDimensions < ActiveRecord::Migration[8.0]
  def up
    # Drop any existing constraints
    execute <<-SQL
      ALTER TABLE images 
      DROP CONSTRAINT IF EXISTS check_embedding_dimensions;
    SQL

    # Drop any existing indexes
    execute <<-SQL
      DROP INDEX IF EXISTS images_embedding_idx;
      DROP INDEX IF EXISTS index_images_on_embedding;
    SQL

    # Drop the existing column
    remove_column :images, :embedding

    # Add the column back with the correct dimensions
    execute <<-SQL
      ALTER TABLE images ADD COLUMN embedding vector(1536);
      
      -- Add the dimension constraint
      ALTER TABLE images 
      ADD CONSTRAINT check_embedding_dimensions 
      CHECK (embedding IS NULL OR vector_dims(embedding) = 1536);
      
      -- Add an index for similarity search
      CREATE INDEX images_embedding_idx ON images USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
    SQL
  end

  def down
    # Drop the column
    remove_column :images, :embedding

    # Add it back with the original dimensions
    execute <<-SQL
      ALTER TABLE images ADD COLUMN embedding vector(512);
      
      -- Add the dimension constraint
      ALTER TABLE images 
      ADD CONSTRAINT check_embedding_dimensions 
      CHECK (embedding IS NULL OR vector_dims(embedding) = 512);
      
      -- Add an index for similarity search
      CREATE INDEX images_embedding_idx ON images USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
    SQL
  end
end 