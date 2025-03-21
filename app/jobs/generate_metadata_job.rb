class GenerateMetadataJob < ApplicationJob
  queue_as :default

  def perform(image)
    return unless image.file.attached?

    begin
      # Get image dimensions and metadata
      analyzer = ActiveStorage::Analyzer::ImageAnalyzer::ImageMagick.new(image.file.blob)
      metadata = analyzer.metadata

      # Update image attributes if needed
      image.name ||= "Image #{Time.current.strftime('%Y%m%d-%H%M%S')}"
      image.description ||= "A #{metadata[:width]}x#{metadata[:height]} #{image.file.content_type.split('/').last.upcase} image"
      image.save if image.changed?
    rescue StandardError => e
      Rails.logger.error("Error generating metadata: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
    end
  end
end 