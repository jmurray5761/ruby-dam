class GenerateEmbeddingJob < ApplicationJob
  queue_as :default

  def perform(image)
    return unless image&.file&.attached?

    begin
      # TODO: Replace this with actual embedding generation logic
      # For now, we'll use a placeholder embedding
      embedding = Array.new(512, 0.0)
      image.update_column(:embedding, embedding)
    rescue StandardError => e
      Rails.logger.error("Error generating embedding for image #{image.id}: #{e.message}")
    end
  end
end 