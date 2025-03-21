class StandardizeVectorIndex < ActiveRecord::Migration[7.1]
  def up
    # Drop existing indexes
    execute "DROP INDEX IF EXISTS index_images_on_embedding"
    execute "DROP INDEX IF EXISTS images_embedding_idx"
    
    # Create new standardized index with cosine similarity
    execute "CREATE INDEX index_images_on_embedding ON images USING ivfflat (embedding vector_cosine_ops) WITH (lists = 1000)"
  end

  def down
    execute "DROP INDEX IF EXISTS index_images_on_embedding"
  end
end 