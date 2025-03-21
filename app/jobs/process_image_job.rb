class ProcessImageJob < ApplicationJob
  queue_as :default

  def perform(image_id)
    image = Image.find_by(id: image_id)
    return unless image&.file&.attached?

    begin
      # Create a thumbnail version of the image
      image.file.open do |file|
        thumbnail = MiniMagick::Image.read(file)
        thumbnail.resize "300x300"
        
        # Attach the thumbnail
        image.thumbnail.attach(
          io: StringIO.new(thumbnail.to_blob),
          filename: "thumbnail_#{image.file.filename}",
          content_type: image.file.content_type
        )
      end
    rescue StandardError => e
      Rails.logger.error("Error processing image #{image_id}: #{e.message}")
    end
  end
end 