class ProcessImageJob < ApplicationJob
  queue_as :default

  def perform(image_id)
    image = Image.find_by(id: image_id)
    return unless image

    begin
      # Set flag to prevent job enqueuing during processing
      image.instance_variable_set(:@skip_job_enqueuing, true)
      
      # Generate name and description if needed
      image.generate_name_and_description_if_needed
      
      # Create thumbnail
      image.file.variant(resize_to_limit: [300, 300]).processed
      
      # Save changes
      image.save!
    rescue StandardError => e
      Rails.logger.error("Error processing image #{image_id}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
    ensure
      # Clear the flag
      image.instance_variable_set(:@skip_job_enqueuing, false)
    end
  end
end 