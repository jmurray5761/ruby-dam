class GenerateImageEmbeddingJob < ApplicationJob
  queue_as :default

  def perform(image_id)
    image = Image.find_by(id: image_id)
    return unless image

    EmbeddingGenerator.generate_for_image(image)
  end

  private

  def extract_image_text(image)
    # For now, just use the image name and description
    # In a real application, you might want to use OCR or other image analysis
    [image.name, image.description].compact.join(" ")
  end
end 