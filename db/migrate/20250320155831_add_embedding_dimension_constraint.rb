class AddEmbeddingDimensionConstraint < ActiveRecord::Migration[7.1]
  def up
    execute <<-SQL
      ALTER TABLE images 
      ADD CONSTRAINT check_embedding_dimensions 
      CHECK (embedding IS NULL OR vector_dims(embedding) = 512);
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE images 
      DROP CONSTRAINT check_embedding_dimensions;
    SQL
  end
end
