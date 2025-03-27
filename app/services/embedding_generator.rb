require 'openai'
require 'tempfile'
require 'base64'

class EmbeddingGenerator
  def self.generate_for_image(image)
    new(image).generate
  end

  def self.generate_for_text(text)
    new(nil).generate_text_embedding(text)
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

  def generate_text_embedding(text)
    begin
      # Generate embedding using OpenAI's embeddings API
      response = @client.embeddings(
        parameters: {
          model: "text-embedding-3-small",
          input: text
        }
      )

      # Get the embedding from the response
      embedding = response.dig("data", 0, "embedding")

      # Ensure the embedding has the correct dimensions
      if embedding && embedding.length == Image::EMBEDDING_DIMENSION
        embedding
      else
        Rails.logger.error "Invalid embedding dimensions: got #{embedding&.length}, expected #{Image::EMBEDDING_DIMENSION}"
        nil
      end
    rescue StandardError => e
      Rails.logger.error "Error generating text embedding: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      nil
    end
  end

  private

  def extract_image_text(image)
    # We use a text-based embedding approach for both image and text search.
    # For images, we use the image's name and description as the text input.
    # This ensures consistency between image and text embeddings, allowing us to
    # search across both modalities using the same vector space.
    [image.name, image.description].compact.join(" ")
  end
end 