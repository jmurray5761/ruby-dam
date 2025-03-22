FactoryBot.define do
  factory :image do
    sequence(:name) { |n| "Test Image #{n}" }
    sequence(:description) { |n| "Description for test image #{n}" }
    embedding { nil }

    trait :with_file do
      transient do
        tmp_path { Rails.root.join('tmp/storage/test_image.jpg') }
      end

      after(:build) do |image, evaluator|
        FileUtils.mkdir_p(File.dirname(evaluator.tmp_path))
        
        unless File.exist?(evaluator.tmp_path)
          MiniMagick::Tool::Convert.new do |convert|
            convert.size '200x200'
            convert << 'xc:white'
            convert << evaluator.tmp_path
          end
        end

        image.file.attach(
          io: File.open(evaluator.tmp_path),
          filename: 'test_image.jpg',
          content_type: 'image/jpeg',
          metadata: { 
            'width' => 200,
            'height' => 200,
            'identified' => true
          }
        )
      end

      after(:create) do |image, evaluator|
        File.delete(evaluator.tmp_path) if File.exist?(evaluator.tmp_path)
      end
    end

    trait :with_small_file do
      transient do
        tmp_path { Rails.root.join('tmp/storage/small_test_image.jpg') }
      end

      after(:build) do |image, evaluator|
        FileUtils.mkdir_p(File.dirname(evaluator.tmp_path))
        
        unless File.exist?(evaluator.tmp_path)
          MiniMagick::Tool::Convert.new do |convert|
            convert.size '50x50'
            convert << 'xc:white'
            convert << evaluator.tmp_path
          end
        end

        image.file.attach(
          io: File.open(evaluator.tmp_path),
          filename: 'small_test_image.jpg',
          content_type: 'image/jpeg',
          metadata: { 
            'width' => 50,
            'height' => 50,
            'identified' => true
          }
        )
      end

      after(:create) do |image, evaluator|
        File.delete(evaluator.tmp_path) if File.exist?(evaluator.tmp_path)
      end
    end

    trait :with_large_file do
      transient do
        tmp_path { Rails.root.join('tmp/storage/large_test_image.jpg') }
      end

      after(:build) do |image, evaluator|
        FileUtils.mkdir_p(File.dirname(evaluator.tmp_path))
        
        unless File.exist?(evaluator.tmp_path)
          MiniMagick::Tool::Convert.new do |convert|
            convert.size '5000x5000'
            convert << 'xc:white'
            convert << evaluator.tmp_path
          end
        end

        image.file.attach(
          io: File.open(evaluator.tmp_path),
          filename: 'large_test_image.jpg',
          content_type: 'image/jpeg',
          metadata: { 
            'width' => 5000,
            'height' => 5000,
            'identified' => true
          }
        )
      end

      after(:create) do |image, evaluator|
        File.delete(evaluator.tmp_path) if File.exist?(evaluator.tmp_path)
      end
    end

    trait :with_invalid_file_type do
      after(:build) do |image|
        image.file.attach(
          io: StringIO.new('Invalid file content'),
          filename: 'test.txt',
          content_type: 'text/plain'
        )
        image.skip_validation_in_test = true
      end
    end

    trait :with_malformed_gif do
      after(:build) do |image|
        # Create a minimal GIF header with invalid data
        gif_data = StringIO.new
        gif_data.write('GIF89a') # GIF header
        gif_data.write([50, 50].pack('S<S<')) # Width and height as 16-bit integers
        gif_data.write('Invalid GIF data')
        gif_data.rewind

        image.file.attach(
          io: gif_data,
          filename: 'malformed.gif',
          content_type: 'image/gif'
        )
        image.skip_validation_in_test = true
      end
    end

    trait :with_embedding do
      after(:build) do |image|
        image.embedding = Array.new(1536) { rand(-1.0..1.0) }
      end
    end

    trait :without_embedding do
      embedding { nil }
    end

    trait :with_small_dimensions do
      after(:build) do |image|
        tmp_path = Rails.root.join('tmp/small_dimensions_test_image.jpg')
        MiniMagick::Tool::Convert.new do |convert|
          convert.size '80x80'
          convert.xc 'white'
          convert << tmp_path.to_s
        end
        image.file.attach(
          io: File.open(tmp_path),
          filename: 'small_dimensions_test_image.jpg',
          content_type: 'image/jpeg',
          metadata: {
            'width' => 80,
            'height' => 80,
            'identified' => true
          }
        )
        File.delete(tmp_path) if File.exist?(tmp_path)
      end
    end

    trait :skip_validation do
      after(:build) do |image|
        image.skip_validation_in_test = true
      end
    end

    trait :skip_callbacks do
      after(:build) do |image|
        image.skip_validation_in_test = true
        image.class.skip_callback(:create, :after, :enqueue_jobs)
      end

      after(:create) do |image|
        image.class.set_callback(:create, :after, :enqueue_jobs)
      end
    end
  end
end 