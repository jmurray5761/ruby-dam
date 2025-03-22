require 'rails_helper'
require 'rake'

RSpec.describe 'images:generate_embeddings' do
  include ActiveJob::TestHelper

  before do
    ActiveJob::Base.queue_adapter = :test
    Rake.application.rake_require 'tasks/images'
    Rake::Task.define_task(:environment)
  end

  it 'enqueues embedding generation for images without embeddings' do
    # Create some test images
    image1 = create(:image, :with_file)
    image2 = create(:image, :with_file)
    image3 = create(:image, :with_file)

    # Clear any jobs that were enqueued during creation
    clear_enqueued_jobs

    # Set some images to have embeddings
    vector = Array.new(1536) { rand(-1.0..1.0) }
    image2.update_columns(embedding: vector)

    # Run the rake task
    Rake::Task['images:generate_embeddings'].invoke

    # Verify that only images without embeddings were enqueued
    expect(GenerateImageEmbeddingJob).to have_been_enqueued.exactly(2).times
    expect(GenerateImageEmbeddingJob).to have_been_enqueued.with(image1.id)
    expect(GenerateImageEmbeddingJob).to have_been_enqueued.with(image3.id)
    expect(GenerateImageEmbeddingJob).not_to have_been_enqueued.with(image2.id)
  end

  after do
    Rake::Task['images:generate_embeddings'].reenable
  end
end 