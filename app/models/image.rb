class Image < ApplicationRecord
  has_one_attached :file

  # Field :name, type: string
  # Field :description, type: text
end