namespace :images do
  desc "Generate embeddings for images without them"
  task generate_embeddings: :environment do
    images = Image.without_embedding
      .joins(:file_attachment)
      .where.not(id: Delayed::Job.where("handler LIKE '%GenerateImageEmbeddingJob%'").select(:id))
    
    if images.any?
      puts "Found #{images.count} images without embeddings. Enqueuing jobs..."
      images.each do |image|
        GenerateImageEmbeddingJob.perform_later(image.id)
      end
      puts "Successfully enqueued #{images.count} jobs."
    else
      puts "No images found that need embeddings."
    end
  end
end 