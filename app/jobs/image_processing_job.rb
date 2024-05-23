class ImageProcessingJob < ApplicationJob
  queue_as :default

  def perform(image_id)
    image = Image.find(image_id)

    if image.generate_name_and_description
      image.send(:generate_name_and_description_if_needed)
    end
  end
end


