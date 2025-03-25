class OpenAiService
  class << self
    def generate_name_and_description(image)
      return { name: "Test Image", description: "Test Description" } if Rails.env.test?

      Rails.logger.info("Making OpenAI API call with image")
      client = OpenAI::Client.new
      
      response = client.chat(
        parameters: {
          model: "gpt-4o-mini",
          messages: [
            {
              role: "user",
              content: [
                {
                  type: "text",
                  text: "Please analyze this image and provide two things:\n1. A four-word name that summarizes the image contents (start with 'Name:')\n2. A detailed description of what you see in the image (start with 'Description:')"
                },
                {
                  type: "image_url",
                  image_url: {
                    url: "data:image/jpeg;base64,#{image}",
                    detail: "high"
                  }
                }
              ]
            }
          ],
          max_tokens: 300,
          temperature: 0.1
        }
      )

      Rails.logger.info("Received OpenAI response: #{response.inspect}")
      
      content = response.dig("choices", 0, "message", "content")
      return nil unless content

      Rails.logger.info("Parsing content: #{content}")
      
      # Try to parse the content and remove asterisks
      name_match = content.match(/Name:\s*(.+?)(?:\n|$)/)
      desc_match = content.match(/Description:\s*(.+?)(?:\n|$)/)

      if name_match && desc_match
        result = {
          name: name_match[1].strip.gsub(/^\*+\s*|\s*\*+$/, ''),
          description: desc_match[1].strip.gsub(/^\*+\s*|\s*\*+$/, '')
        }
        Rails.logger.info("Successfully parsed name and description: #{result.inspect}")
        result
      else
        Rails.logger.warn("Failed to parse content properly. Name match: #{name_match.inspect}, Description match: #{desc_match.inspect}")
        nil
      end
    rescue StandardError => e
      Rails.logger.error("Error generating metadata: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      nil
    end
  end

  def initialize
    @client = OpenAI::Client.new
  end

  def get_embedding(text)
    response = @client.embeddings(
      parameters: {
        model: "text-embedding-ada-002",
        input: text
      }
    )
    response.dig("data", 0, "embedding")
  rescue StandardError => e
    Rails.logger.error("OpenAI API error: #{e.message}")
    nil
  end

  def generate_image_embedding(image)
    return Array.new(512) { 0.0 } if Rails.env.test?

    response = @client.embeddings(
      parameters: {
        model: "text-embedding-ada-002",
        input: generate_image_description(image)
      }
    )

    response["data"][0]["embedding"]
  rescue StandardError => e
    Rails.logger.error("Error generating embedding: #{e.message}")
    raise
  end

  private

  def generate_image_description(image)
    return "Test image description" if Rails.env.test?

    # In a real implementation, this would use image analysis to generate a description
    "Image uploaded at #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}"
  end
end 