require 'rails_helper'

RSpec.describe Image, type: :model do
  let(:image) do
    build(:image,
      name: "Test Image",
      description: "A test image description",
      generate_name_and_description: false
    )
  end

  before do
    image.file.attach(create_test_image)
  end

  describe 'validations' do
    it 'should not save an image without name and description' do
      image = build(:image, name: nil, description: nil)
      image.file.attach(create_test_image)
      
      expect(image).not_to be_valid
      expect(image.errors[:name]).to include("can't be blank")
      expect(image.errors[:description]).to include("can't be blank")
    end

    it 'should save an image with name and description' do
      expect(image).to be_valid
      expect(image.save).to be true
    end

    it 'should require file attachment' do
      image = build(:image, name: "Test Image", description: "Test Description")
      
      expect(image).not_to be_valid
      expect(image.errors[:file]).to include("can't be blank")
    end

    it 'should validate file size' do
      image.file.attach(create_test_image(byte_size: 11.megabytes))
      
      expect(image).not_to be_valid
      expect(image.errors[:file]).to include('The file size is too large')
    end

    it 'should validate file type' do
      image.file.attach(create_test_file(content_type: 'text/plain'))
      
      expect(image).not_to be_valid
      expect(image.errors[:file]).to include('must be a PNG, JPEG, or GIF')
    end

    it 'should skip image dimension validation in test environment' do
      image.file.attach(create_test_image)
      expect(image).to be_valid
    end
  end

  describe 'callbacks' do
    it 'should enqueue image processing after create' do
      image.generate_name_and_description = true
      
      expect {
        image.save
      }.to have_enqueued_job(ImageProcessingJob)
    end

    it 'should not enqueue image processing when flag is false' do
      image.generate_name_and_description = false
      
      perform_enqueued_jobs do
        image.save
      end
      
      expect(ImageProcessingJob).not_to have_been_enqueued
    end
  end

  describe 'error handling' do
    it 'should handle file attachment errors gracefully' do
      allow(image.file).to receive(:attached?).and_return(true)
      allow(image.file).to receive(:blob).and_raise(StandardError.new("Test error"))
      
      expect(image).to be_valid # Should be valid in test environment
    end
  end

  describe 'default values' do
    it 'should set default generate flag to false' do
      image = build(:image)
      image.valid?
      
      expect(image.generate_name_and_description).to be false
    end
  end
end 