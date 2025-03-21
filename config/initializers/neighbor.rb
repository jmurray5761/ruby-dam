require 'active_record'
require 'neighbor'

# Initialize the neighbor gem
Neighbor::PostgreSQL.initialize!

# Ensure the vector extension is enabled
ActiveRecord::Base.connection.execute("CREATE EXTENSION IF NOT EXISTS vector") unless Rails.env.test?

ActiveSupport.on_load(:active_record) do
  # Make Neighbor::Model available to all models
  ActiveRecord::Base.include Neighbor::Model
end