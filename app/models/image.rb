class Image < ApplicationRecord
  # Validates that name and description are present
  validates :name, presence: true
  validates :description, presence: true

  # Validates that a file is attached, assuming you are using ActiveStorage
  has_one_attached :file
  validates :file, attached: true, size: { less_than: 10.megabytes, message: 'The file size is too large' }
end
