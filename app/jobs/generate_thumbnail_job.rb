class GenerateThumbnailJob < ApplicationJob
  queue_as :default

  def perform(image)
    return unless image.file.attached?

    begin
      # Generate a thumbnail variant
      thumbnail = image.file.variant(resize_to_limit: [300, 300]).processed
      
      # Attach the thumbnail
      image.thumbnail.attach(
        io: thumbnail.service_url,
        filename: "thumbnail_#{image.file.filename}",
        content_type: image.file.content_type
      )
    rescue StandardError => e
      Rails.logger.error("Error generating thumbnail: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
    end
  end
end 