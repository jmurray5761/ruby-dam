require 'rails_helper'

RSpec.describe GenerateImageEmbeddingJob, type: :job do
  include ActiveJob::TestHelper

  let(:image) { create(:image, :with_file) }
  let(:mock_embedding) { Array.new(512) { rand(-1.0..1.0) } }

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  describe '#perform' do
    context 'when the image has a file attached' do
      it 'generates and stores an embedding' do
        # Mock the OpenAI client
        mock_client = instance_double(OpenAI::Client)
        allow(OpenAI::Client).to receive(:new).and_return(mock_client)
        
        # Mock the API response
        allow(mock_client).to receive(:embeddings).and_return({
          "data" => [{ "embedding" => mock_embedding }]
        })

        # Perform the job
        described_class.perform_now(image.id)

        # Verify the embedding was stored
        image.reload
        expect(image.embedding.size).to eq(mock_embedding.size)
        image.embedding.zip(mock_embedding).each do |actual, expected|
          expect(actual).to be_within(1e-6).of(expected)
        end
      end

      it 'handles API errors gracefully' do
        # Mock the OpenAI client to raise an error
        mock_client = instance_double(OpenAI::Client)
        allow(OpenAI::Client).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive(:embeddings).and_raise(StandardError.new("API Error"))

        # Perform the job
        expect { described_class.perform_now(image.id) }.not_to raise_error
      end
    end

    context 'when the image has no file attached' do
      let(:image) { build(:image) }

      before do
        allow_any_instance_of(Image).to receive(:validate_file_type).and_return(true)
        allow_any_instance_of(Image).to receive(:validate_file_dimensions).and_return(true)
        allow_any_instance_of(Image).to receive(:validate_file_size).and_return(true)
        image.save(validate: false)
      end

      it 'does not attempt to generate an embedding' do
        expect(OpenAI::Client).not_to receive(:new)
        described_class.perform_now(image.id)
      end
    end
  end
end 