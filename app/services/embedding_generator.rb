require 'openai'
require 'tempfile'
require 'base64'

class EmbeddingGenerator
  def self.generate_for_image(image)
    new(image).generate
  end

  def initialize(image)
    @image = image
    @client = OpenAI::Client.new(access_token: ENV['OPENAI_ACCESS_TOKEN'])
  end

  def generate
    return unless @image.file.attached?

    begin
      # Convert image to base64
      image_data = Base64.strict_encode64(@image.file.download)

      # Generate embedding using OpenAI's embeddings API
      response = @client.embeddings(
        parameters: {
          model: "text-embedding-3-small",
          input: extract_image_text(@image)
        }
      )

      # Get the embedding from the response
      embedding = response.dig("data", 0, "embedding")

      # Ensure the embedding has the correct dimensions
      if embedding && embedding.length == Image::EMBEDDING_DIMENSION
        # Store the embedding in the database with validation bypass
        @image.update_column(:embedding, embedding)
        true
      else
        Rails.logger.error "Invalid embedding dimensions: got #{embedding&.length}, expected #{Image::EMBEDDING_DIMENSION}"
        false
      end
    rescue StandardError => e
      Rails.logger.error "Error generating embedding: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      false
    end
  end

  private

  def extract_image_text(image)
    # For now, we'll use the image name and description as text input
    # In a real application, you might want to use OCR or other image analysis
    [image.name, image.description].compact.join(" ")
  end
end 