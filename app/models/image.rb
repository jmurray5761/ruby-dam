class Image < ApplicationRecord
  has_one_attached :file

  validates :name, presence: true, unless: -> { generate_name_and_description }
  validates :description, presence: true, unless: -> { generate_name_and_description }
  validates :file, attached: true, size: { less_than: 10.megabytes, message: 'The file size is too large' }

  attr_accessor :generate_name_and_description

  after_commit :generate_name_and_description_if_needed

  private
  def enqueue_image_processing
    ImageProcessingJob.perform_later(self.id) if generate_name_and_description && file.attached?
  end
  def generate_name_and_description_if_needed
    return unless generate_name_and_description && file.attached? && name.blank? && description.blank?

    encoded_image = encode_image(file)
    client = OpenAI::Client.new do |config|
      config.request :retry, max: 2, interval: 0.05, backoff_factor: 2
    end

    message = {
      "model": "gpt-4o",
      "messages": [
        {
          "role": "user",
          "content": [
            {
              "type": "text",
              "text": "What's a four word name that summarizes the image contents?  What’s in this image?"
            },
            {
              "type": "image_url",
              "image_url": {
                "url": "data:image/jpeg;base64,#{encoded_image}"
              }
            }
          ]
        }
      ],
      "max_tokens": 300,
      "temperature": 0.1
    }

    begin
      response = client.chat(parameters: message)

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

  def encode_image(attachment)
    if attachment.attached?
      Base64.strict_encode64(attachment.download)
    else
      ""
    end
  end

  def parse_generated_content(content)
    lines = content.split("\n", 2)
    name = lines[0].split(": ", 2).last.strip.gsub(/\A"|"\Z|\.\Z/, '')
    description = lines[1].split(": ", 2).last.strip if lines.length > 1
    [name, description]
  end
end
