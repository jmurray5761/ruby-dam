class AddEmbeddingToImages < ActiveRecord::Migration[7.1]
  def up
    enable_extension 'vector' unless extension_enabled?('vector')
    execute "ALTER TABLE images ADD COLUMN embedding vector(512)"
    execute "CREATE INDEX ON images USING ivfflat (embedding vector_l2_ops) WITH (lists = 100)"
  end

  def down
    execute "DROP INDEX IF EXISTS images_embedding_idx"
    remove_column :images, :embedding
  end
end
