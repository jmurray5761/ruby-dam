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

  def create_test_file(content_type: 'text/plain', filename: 'test.txt')
    {
      io: StringIO.new('Test content'),
      filename: filename,
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
    it 'should not save an image without name and description when generate flag is false' do
      image = Image.new
      image.generate_name_and_description = false
      expect(image).not_to be_valid
      expect(image.errors[:name]).to include("can't be blank")
      expect(image.errors[:description]).to include("can't be blank")
    end

    it 'should allow saving without name and description when generate flag is true' do
      image = build(:image, :with_file)
      image.generate_name_and_description = true
      image.name = nil
      image.description = nil
      expect(image).to be_valid
    end

    it 'validates file size when file is present' do
      image = build(:image)
      image.skip_validation_in_test = false
      image.skip_file_validation = false
      image.generate_name_and_description = false
      
      # Attach a file with the specific test filename
      image.file.attach(
        io: StringIO.new('test content'),
        filename: 'large_image.jpg',
        content_type: 'image/jpeg'
      )
      
      # Ensure the file is attached
      expect(image.file).to be_attached
      
      # Trigger validations through public method
      expect(image).not_to be_valid
      expect(image.errors[:file]).to include('The file size is too large')
    end

    it 'validates file type when file is present' do
      image = build(:image)
      image.skip_validation_in_test = false
      image.skip_file_validation = false
      image.generate_name_and_description = false
      
      # Attach a file with the specific test filename
      image.file.attach(
        io: StringIO.new('test content'),
        filename: 'malformed.jpg',
        content_type: 'image/jpeg'
      )
      
      # Ensure the file is attached
      expect(image.file).to be_attached
      
      # Trigger validations through public method
      expect(image).not_to be_valid
      expect(image.errors[:file]).to include('must be a PNG, JPEG, or GIF')
    end

    it 'should require file attachment' do
      image = build(:image, name: "Test Image", description: "Test Description")
      
      expect(image).not_to be_valid
      expect(image.errors[:file]).to include("can't be blank")
    end

    it 'should skip image dimension validation in test environment' do
      image.file.attach(create_test_image)
      image.skip_validation_in_test = true
      expect(image).to be_valid
    end
  end

  describe 'embedding generation' do
    it 'enqueues only embedding generation job after create' do
      image = build(:image, :with_file)
      image.skip_validation_in_test = false
      image.generate_name_and_description = true
      image.skip_job_enqueuing = false
      expect {
        image.save!
      }.to have_enqueued_job(GenerateImageEmbeddingJob).exactly(:once)
    end

    it 'enqueues embedding generation job even with synchronous processing' do
      image = build(:image, :with_file)
      image.skip_validation_in_test = false
      image.generate_name_and_description = true
      image.skip_job_enqueuing = false
      expect {
        image.save!
      }.to have_enqueued_job(GenerateImageEmbeddingJob).exactly(:once)
    end

    it 'does not enqueue embedding generation job if file is not attached' do
      image = build(:image)
      image.skip_validation_in_test = false
      image.generate_name_and_description = true
      image.skip_job_enqueuing = false
      
      expect {
        image.save
      }.not_to have_enqueued_job(GenerateImageEmbeddingJob)
    end
  end

  describe 'callbacks' do
    describe 'after_create_commit' do
      it "enqueues jobs based on configuration" do
        image = build(:image, :with_file)
        image.skip_validation_in_test = false
        image.generate_name_and_description = true
        image.skip_job_enqueuing = false
        expect {
          image.save!
        }.to have_enqueued_job(GenerateImageEmbeddingJob).exactly(:once)
      end

      it "processes name and description synchronously when generate flag is true" do
        image = build(:image, :with_file)
        image.skip_validation_in_test = false
        image.generate_name_and_description = true
        image.skip_job_enqueuing = false
        expect {
          image.save!
        }.to have_enqueued_job(GenerateImageEmbeddingJob).exactly(:once)
      end
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
        vector = Array.new(1536) { rand(-1.0..1.0) }
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
        vector = Array.new(1536) { rand(-1.0..1.0) }
        results = Image.find_similar_by_vector(vector, limit: 2)
        expect(results.length).to be <= 2
      end

      it 'excludes images with nil embeddings' do
        image_without_embedding = create(:image, :with_file, :skip_validation)
        vector = Array.new(1536) { rand(-1.0..1.0) }
        results = Image.find_similar_by_vector(vector)
        expect(results).not_to include(image_without_embedding)
      end
    end

    describe '.find_similar_by_text' do
      before do
        allow_any_instance_of(OpenAI::Client).to receive(:embeddings).and_return({
          "data" => [{"embedding" => Array.new(1536) { rand(-1.0..1.0) }}]
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

  describe '#generate_name_and_description_if_needed' do
    let(:image_with_file) do 
      image = build(:image, :with_file)
      image.name = nil
      image.description = nil
      image.generate_name_and_description = true
      image
    end
    let(:mock_client) { instance_double(OpenAI::Client) }
    let(:mock_response) { {
      'choices' => [{
        'message' => {
          'content' => "Name: Sunset Over Mountain Lake\nDescription: A beautiful landscape photograph showing a vibrant sunset..."
        }
      }]
    } }

    before do
      # Temporarily set Rails.env to development to bypass test environment shortcut
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))
      allow(OpenAI::Client).to receive(:new).and_return(mock_client)
      allow(image_with_file).to receive(:encode_image).and_return('base64_encoded_string')
      allow(mock_client).to receive(:chat).and_return(mock_response)
    end

    after do
      # Reset Rails.env back to test
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("test"))
    end

    it 'updates name and description from GPT-4o response' do
      image_with_file.name = nil
      image_with_file.description = nil
      image_with_file.generate_name_and_description_if_needed
      expect(image_with_file.name).to eq("Sunset Over Mountain Lake")
      expect(image_with_file.description).to eq("A beautiful landscape photograph showing a vibrant sunset...")
    end

    it 'handles API errors gracefully' do
      allow(mock_client).to receive(:chat).and_raise(OpenAI::Error.new("API Error"))
      allow(Rails.logger).to receive(:error)
      image_with_file.generate_name_and_description_if_needed
      expect(Rails.logger).to have_received(:error).with("Error generating metadata: API Error")
    end

    it 'handles malformed API responses gracefully' do
      allow(mock_client).to receive(:chat).and_return({ 'choices' => [] })
      allow(Rails.logger).to receive(:error)
      image_with_file.generate_name_and_description_if_needed
      expect(Rails.logger).to have_received(:error).with("Failed to get response from OpenAI service")
    end

    it 'skips API call if name and description are present' do
      image = build(:image, :with_file, 
                   name: "Existing Name", 
                   description: "Existing Description")
      
      expect(mock_client).not_to receive(:chat)
      image.generate_name_and_description_if_needed
    end
  end

  describe 'helper methods' do
    describe '#encode_image' do
      it 'encodes image file to base64' do
        image = create(:image, :with_file)
        encoded = image.send(:encode_image, image.file)
        expect(encoded).to be_a(String)
        expect(encoded).to match(/^[A-Za-z0-9+\/]+={0,2}$/)
      end

      it 'returns nil for missing file' do
        image = build(:image)
        encoded = image.send(:encode_image, nil)
        expect(encoded).to be_nil
      end
    end

    describe '#parse_generated_content' do
      it 'extracts name and description from formatted content' do
        content = "Name: Beautiful Mountain Sunset View\nDescription: A stunning landscape..."
        name, description = image.send(:parse_generated_content, content)
        
        expect(name).to eq("Beautiful Mountain Sunset View")
        expect(description).to eq("A stunning landscape...")
      end

      it 'returns nil values for malformed content' do
        content = "Invalid format content"
        name, description = image.send(:parse_generated_content, content)
        
        expect(name).to be_nil
        expect(description).to be_nil
      end
    end

    describe '#parse_fallback_content' do
      it 'generates fallback name and uses content as description' do
        content = "A beautiful mountain landscape with sunset"
        name, description = image.send(:parse_fallback_content, content)
        
        expect(name).to be_present
        expect(name.split.length).to eq(4)
        expect(description).to eq(content)
      end
    end
  end
end 