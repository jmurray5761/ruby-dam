class Image < ApplicationRecord
  has_one_attached :file

  validates :name, presence: true, unless: -> { generate_name_and_description }
  validates :description, presence: true, unless: -> { generate_name_and_description }
  validates :file, attached: true, size: { less_than: 10.megabytes, message: 'The file size is too large' }

  attr_accessor :generate_name_and_description

  after_save :generate_name_and_description_if_needed

  private

  def generate_name_and_description_if_needed
    return unless generate_name_and_description && file.attached? && name.blank? && description.blank?

    file_url = Rails.application.routes.url_helpers.rails_blob_url(file, only_path: true)

    client = OpenAI::Client.new do |config|
      config.request :retry, max: 2, interval: 0.05, backoff_factor: 2
    end

    message = {
      "content": "Please generate a name and a description for the image file. The name should be a concise title, up to six words separated by a single space, that accurately describes the content of the image. The name should not contain any quotes. Additionally, create a detailed and descriptive long description that can be used by a screen reader to help a visually impaired user understand the image. Ensure the description is thorough and covers the key elements and context of the image. Image file: #{file_url}",
      "role": 'user'
    }

    begin
      response = client.chat(
        parameters: {
          model: 'gpt-4',
          messages: [message],
          temperature: 0.5
        }
      )

      if response['choices'].present?
        content = response['choices'].first['message']['content']
        generated_name, generated_description = parse_generated_content(content)
        update_columns(name: generated_name, description: generated_description)
      else
        Rails.logger.error("OpenAI response did not contain choices: #{response}")
      end

    rescue OpenAI::Error => e
      Rails.logger.error("OpenAI API call failed: #{e.message}")
      errors.add(:base, "OpenAI API call failed: #{e.message}")
      raise ActiveRecord::Rollback
    rescue => e
      Rails.logger.error("Unexpected error: #{e.message}")
      errors.add(:base, "Unexpected error occurred: #{e.message}")
      raise ActiveRecord::Rollback
    end
  end

  def parse_generated_content(content)
    name, description = content.split("\n", 2).map { |line| line.split(": ", 2).last }
    [name, description]
  end
end
