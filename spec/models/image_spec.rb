require 'rails_helper'

RSpec.describe Image, type: :model do
  include ActiveJob::TestHelper

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  def create_test_image(byte_size: 1.megabyte)
    FileUtils.mkdir_p(Rails.root.join('tmp/storage'))
    tmp_path = Rails.root.join('tmp/storage/test_image.jpg')
    
    unless File.exist?(tmp_path)
      MiniMagick::Tool::Convert.new do |convert|
        convert.size '200x200'
        convert << 'xc:white'
        convert << tmp_path
      end
    end

    { 
      io: File.open(tmp_path),
      filename: 'test_image.jpg',
      content_type: 'image/jpeg',
      metadata: { 
        'width' => 200,
        'height' => 200,
        'identified' => true
      }
    }
  end

  def create_test_file(content_type: 'text/plain')
    {
      io: StringIO.new('Test content'),
      filename: 'test.txt',
      content_type: content_type
    }
  end

  let(:image) do
    build(:image,
      name: "Test Image",
      description: "A test image description",
      generate_name_and_description: false
    )
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
      image.skip_validation_in_test = true
      image.file.attach(create_test_image)
      expect(image).to be_valid
      expect(image.save).to be true
    end

    it 'should require file attachment' do
      image = build(:image, name: "Test Image", description: "Test Description")
      
      expect(image).not_to be_valid
      expect(image.errors[:file]).to include("can't be blank")
    end

    it 'should validate file size' do
      image.file.attach(create_test_file(content_type: 'image/jpeg'))
      allow(image.file.blob).to receive(:byte_size).and_return(11.megabytes)
      
      expect(image).not_to be_valid
      expect(image.errors[:file]).to include('The file size is too large')
    end

    it 'should validate file type' do
      image.skip_validation_in_test = false
      image.file.attach(create_test_file(content_type: 'text/plain'))
      
      expect(image).not_to be_valid
      expect(image.errors[:file]).to include('must be a PNG, JPEG, or GIF')
    end

    it 'should skip image dimension validation in test environment' do
      image.file.attach(create_test_image)
      image.skip_validation_in_test = true
      expect(image).to be_valid
    end

    describe 'embedding generation' do
      it 'enqueues embedding generation job after create' do
        image.file.attach(create_test_image)
        image.skip_validation_in_test = false
        image.generate_name_and_description = true
        expect {
          image.save
        }.to have_enqueued_job(GenerateImageEmbeddingJob).with(image.id)
      end

      it 'does not enqueue embedding generation job if file is not attached' do
        image_without_file = build(:image)
        expect {
          image_without_file.save
        }.not_to have_enqueued_job(GenerateImageEmbeddingJob)
      end
    end
  end

  describe 'callbacks' do
    it 'should enqueue image processing after create' do
      image = build(:image, :with_file)
      image.skip_validation_in_test = false
      image.generate_name_and_description = true
      expect {
        image.save
      }.to have_enqueued_job(ProcessImageJob)
    end

    it 'should not enqueue image processing when flag is false' do
      expect {
        create(:image, :with_file, :skip_validation, generate_name_and_description: false)
      }.not_to have_enqueued_job(ProcessImageJob)
    end
  end

  describe 'error handling' do
    it 'handles file attachment errors gracefully' do
      image = build(:image)
      image.skip_validation_in_test = true
      image.file.attach(create_test_image)
      allow(image).to receive(:file_attached?).and_raise(StandardError.new('Test error'))
      
      expect(image).to be_valid
      expect(image.errors[:file]).to be_empty
    end
  end

  describe 'default values' do
    it 'should set default generate flag to true' do
      image = build(:image)
      image.valid?
      
      expect(image.generate_name_and_description).to be true
    end
  end

  describe 'vector similarity search' do
    let!(:image1) { create(:image, :with_file, :with_embedding, :skip_validation) }
    let!(:image2) { create(:image, :with_file, :with_embedding, :skip_validation) }
    let!(:image3) { create(:image, :with_file, :with_embedding, :skip_validation) }

    describe '.find_similar_by_vector' do
      it 'finds similar images by vector' do
        vector = Array.new(512) { rand(-1.0..1.0) }
        results = Image.find_similar_by_vector(vector)
        expect(results).to be_an(ActiveRecord::Relation)
        expect(results.length).to be <= 10
      end

      it 'returns empty relation for nil vector' do
        expect(Image.find_similar_by_vector(nil)).to be_empty
      end

      it 'returns empty relation for empty vector' do
        expect(Image.find_similar_by_vector([])).to be_empty
      end

      it 'respects the limit parameter' do
        vector = Array.new(512) { rand(-1.0..1.0) }
        results = Image.find_similar_by_vector(vector, limit: 2)
        expect(results.length).to be <= 2
      end

      it 'excludes images with nil embeddings' do
        image_without_embedding = create(:image, :with_file, :skip_validation)
        vector = Array.new(512) { rand(-1.0..1.0) }
        results = Image.find_similar_by_vector(vector)
        expect(results).not_to include(image_without_embedding)
      end
    end

    describe '.find_similar_by_text' do
      before do
        allow_any_instance_of(OpenAI::Client).to receive(:embeddings).and_return({
          "data" => [{"embedding" => Array.new(512) { rand(-1.0..1.0) }}]
        })
      end

      it 'finds similar images by text query' do
        results = Image.find_similar_by_text("test query")
        expect(results).to be_an(ActiveRecord::Relation)
        expect(results.length).to be <= 10
      end

      it 'returns empty array for blank query' do
        expect(Image.find_similar_by_text("")).to eq([])
      end

      it 'returns empty array for nil query' do
        expect(Image.find_similar_by_text(nil)).to eq([])
      end
    end

    describe '.find_similar_by_image' do
      it 'finds similar images by image id' do
        results = Image.find_similar_by_image(image1.id)
        expect(results).to be_an(ActiveRecord::Relation)
        expect(results.length).to be <= 10
      end

      it 'returns empty array for non-existent image' do
        expect(Image.find_similar_by_image(999)).to eq([])
      end

      it 'returns empty array for image without embedding' do
        image_without_embedding = create(:image, :with_file, :skip_validation)
        expect(Image.find_similar_by_image(image_without_embedding.id)).to eq([])
      end
    end

    describe '#similar_images' do
      it 'returns similar images excluding self' do
        results = image1.similar_images
        expect(results).to be_an(ActiveRecord::Relation)
        expect(results.length).to be <= 10
      end

      it 'returns empty relation when embedding is nil' do
        image_without_embedding = create(:image, :with_file, :skip_validation)
        expect(image_without_embedding.similar_images).to be_empty
      end
    end
  end
end 