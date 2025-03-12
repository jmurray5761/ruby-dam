class Image < ApplicationRecord
  has_one_attached :file

  validates :name, presence: true, unless: -> { generate_name_and_description }
  validates :description, presence: true, unless: -> { generate_name_and_description }
  validates :file, attached: true
  validate :validate_file_type
  validate :validate_file_size
  validate :handle_file_errors

  attr_accessor :generate_name_and_description

  before_validation :set_default_generate_flag
  after_commit :validate_image_dimensions, on: :create
  after_commit :generate_name_and_description_if_needed, on: :create
  after_commit :enqueue_image_processing, on: :create, if: :should_process?

  private

  def set_default_generate_flag
    self.generate_name_and_description = false if generate_name_and_description.nil?
  end

  def should_process?
    Rails.logger.info("Checking should_process? for image #{id}")
    Rails.logger.info("File attached?: #{file.attached?}")
    Rails.logger.info("generate_name_and_description value: #{generate_name_and_description}")
    Rails.logger.info("generate_name_and_description nil?: #{generate_name_and_description.nil?}")
    
    result = file.attached? && !generate_name_and_description.nil? && generate_name_and_description == true
    Rails.logger.info("should_process? result: #{result}")
    result
  end

  def handle_file_errors
    return unless file.respond_to?(:errors) && file.errors.any?
    file.errors.each do |error|
      errors.add(:file, error.message)
    end
  end

  def validate_file_type
    return unless file.attached?
    
    unless file.content_type.in?(%w[image/png image/jpeg image/gif])
      errors.add(:file, 'must be a PNG, JPEG, or GIF')
      throw(:abort)
    end
  end

  def validate_file_size
    return unless file.attached?
    
    if file.byte_size > 10.megabytes
      errors.add(:file, 'The file size is too large')
      throw(:abort)
    end
  end

  def validate_image_dimensions
    return unless file.attached?

    begin
      Rails.logger.info("Starting dimension validation for image #{id}")
      Rails.logger.info("File attached: #{file.attached?}")
      Rails.logger.info("File blob present: #{file.blob.present?}")
      Rails.logger.info("File filename: #{file.filename}")
      Rails.logger.info("File content type: #{file.content_type}")

      # First try to get dimensions directly from the file
      dimensions = get_image_dimensions
      if dimensions
        width, height = dimensions
        Rails.logger.info("Got dimensions directly from file: #{width}x#{height}")
      else
        # If direct method fails, try through ActiveStorage analysis
        Rails.logger.info("Attempting to analyze file through ActiveStorage")
        file.blob.analyze unless file.analyzed?
        metadata = file.metadata
        Rails.logger.info("Image metadata: #{metadata.inspect}")
        
        if metadata.nil?
          Rails.logger.error("No metadata available")
          errors.add(:file, "Could not determine image dimensions (no metadata)")
          return
        end

        if metadata['width'].nil? || metadata['height'].nil?
          Rails.logger.error("No width/height in metadata")
          errors.add(:file, "Could not determine image dimensions (no width/height)")
          return
        end

        width = metadata['width'].to_i
        height = metadata['height'].to_i
      end
      
      Rails.logger.info("Final image dimensions: #{width}x#{height}")
      
      if width < 200 || height < 200
        errors.add(:file, 'dimensions must be at least 200x200 pixels')
      end
    rescue ActiveStorage::FileNotFoundError => e
      Rails.logger.error("File not found during dimension check: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      errors.add(:file, "File not found during dimension check")
    rescue StandardError => e
      Rails.logger.error("Error checking dimensions: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      errors.add(:file, "Error checking dimensions: #{e.message}")
    end
  end

  def get_image_dimensions
    return nil unless file.attached?

    begin
      Rails.logger.info("Attempting to get dimensions using MiniMagick")
      Rails.logger.info("File path: #{file.path}")
      
      # Use ImageMagick to get dimensions
      image = MiniMagick::Image.open(file.download)
      dimensions = [image.width, image.height]
      Rails.logger.info("Successfully got dimensions: #{dimensions}")
      dimensions
    rescue StandardError => e
      Rails.logger.error("Failed to get image dimensions: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      nil
    end
  end

  def generate_name_and_description_if_needed
    Rails.logger.info("Starting generate_name_and_description_if_needed for image #{id}")
    Rails.logger.info("should_process? result: #{should_process?}")
    Rails.logger.info("generate_name_and_description value: #{generate_name_and_description}")
    Rails.logger.info("name blank?: #{name.blank?}")
    Rails.logger.info("description blank?: #{description.blank?}")

    return unless should_process? && (name.blank? || description.blank?)

    Rails.logger.info("Starting name and description generation for image #{id}")
    
    begin
      encoded_image = encode_image(file)
      if encoded_image.blank?
        Rails.logger.error("Failed to encode image")
        return
      end
      
      Rails.logger.info("Image encoded successfully for image #{id}")

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
                "text": "Please analyze this image and provide two things:\n1. A four-word name that summarizes the image contents (start with 'Name:')\n2. A detailed description of what you see in the image (start with 'Description:')"
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

      Rails.logger.info("Making OpenAI API call for image #{id}")
      response = client.chat(parameters: message)
      Rails.logger.info("Received OpenAI response for image #{id}")
      Rails.logger.info("OpenAI response: #{response.inspect}")

      if response['choices'].present?
        content = response['choices'].first['message']['content']
        Rails.logger.info("Parsing OpenAI response content for image #{id}: #{content}")
        generated_name, generated_description = parse_generated_content(content)
        Rails.logger.info("Parsed name: #{generated_name}")
        Rails.logger.info("Parsed description: #{generated_description}")
        
        if generated_name && generated_description
          update_columns(name: generated_name, description: generated_description)
          Rails.logger.info("Successfully generated name and description for image #{id}")
        else
          # If parsing failed, try to use the content as a description and generate a name
          Rails.logger.info("Attempting fallback parsing")
          fallback_name, fallback_description = parse_fallback_content(content)
          if fallback_name && fallback_description
            update_columns(name: fallback_name, description: fallback_description)
            Rails.logger.info("Successfully generated name and description using fallback method")
          else
            Rails.logger.error("Failed to parse OpenAI response for image #{id}")
          end
        end
      else
        Rails.logger.error("OpenAI response did not contain choices for image #{id}: #{response}")
      end

    rescue OpenAI::Error => e
      Rails.logger.error("OpenAI API call failed for image #{id}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
    rescue StandardError => e
      Rails.logger.error("Unexpected error for image #{id}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
    end
  end

  def encode_image(attachment)
    return "" unless attachment.attached?
    
    begin
      Base64.strict_encode64(attachment.download)
    rescue StandardError => e
      Rails.logger.error("Failed to encode image: #{e.message}")
      ""
    end
  end

  def parse_generated_content(content)
    return [nil, nil] unless content.present?

    lines = content.split("\n")
    name_line = lines.find { |line| line.start_with?("Name:") }
    description_line = lines.find { |line| line.start_with?("Description:") }

    return [nil, nil] unless name_line && description_line

    name = name_line.split(": ", 2).last.strip.gsub(/\A"|"\Z|\.\Z/, '')
    description = description_line.split(": ", 2).last.strip

    [name, description]
  end

  def parse_fallback_content(content)
    return [nil, nil] unless content.present?

    # Use the first sentence as the name (up to 4 words)
    sentences = content.split(/[.!?]+/)
    first_sentence = sentences.first.strip
    words = first_sentence.split
    name = words[0..3].join(" ")

    # Use the full content as the description
    description = content.strip

    [name, description]
  end

  def enqueue_image_processing
    ImageProcessingJob.perform_later(id)
  end
end
