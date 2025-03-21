class ImageProcessingJob < ApplicationJob
  queue_as :default

  def perform(image_id)
    image = Image.find_by(id: image_id)
    return unless image&.file&.attached?

    begin
      # Generate thumbnail
      image.file.variant(resize_to_limit: [800, 800]).processed

      # Generate metadata
      dimensions = get_dimensions(image)
      if dimensions
        image.name ||= File.basename(image.file.filename.to_s)
        image.description ||= "A #{dimensions[:width]}x#{dimensions[:height]} #{image.file.content_type.split('/').last.upcase} image"
        image.save
      end
    rescue StandardError => e
      Rails.logger.error("Error processing image #{image_id}: #{e.message}")
    end
  end

  private

  def get_dimensions(image)
    return unless image.file.attached?

    if image.file.blob.metadata['width'] && image.file.blob.metadata['height']
      { width: image.file.blob.metadata['width'], height: image.file.blob.metadata['height'] }
    else
      analyzer = ActiveStorage::Analyzer::ImageAnalyzer::ImageMagick.new(image.file.blob)
      metadata = analyzer.metadata
      { width: metadata[:width], height: metadata[:height] }
    end
  rescue StandardError => e
    Rails.logger.error("Error getting image dimensions: #{e.message}")
    nil
  end
end


