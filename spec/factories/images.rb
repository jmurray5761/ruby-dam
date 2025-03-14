FactoryBot.define do
  factory :image do
    sequence(:name) { |n| "Test Image #{n}" }
    description { "Test Description" }
    generate_name_and_description { false }

    trait :with_file do
      after(:build) do |image|
        # Create a file that's large enough to be considered 200x200 pixels
        file_content = '0' * 2.kilobytes
        file = Rack::Test::UploadedFile.new(
          StringIO.new(file_content),
          'image/jpeg',
          true,
          original_filename: 'test_image.jpg'
        )
        image.file.attach(file)
      end
    end

    trait :with_small_file do
      after(:build) do |image|
        # Create a file that's small enough to be considered 50x50 pixels
        file_content = '0' * 500
        file = Rack::Test::UploadedFile.new(
          StringIO.new(file_content),
          'image/jpeg',
          true,
          original_filename: 'small_image.jpg'
        )
        image.file.attach(file)
      end
    end

    trait :with_large_file do
      after(:build) do |image|
        # Create a file that's too large (> 5MB)
        file_content = '0' * 6.megabytes
        file = Rack::Test::UploadedFile.new(
          StringIO.new(file_content),
          'image/jpeg',
          true,
          original_filename: 'large_image.jpg'
        )
        image.file.attach(file)
      end
    end

    trait :with_generated_metadata do
      generate_name_and_description { true }
      with_file
    end

    trait :with_invalid_file_type do
      after(:build) do |image|
        file = Rails.root.join('spec', 'fixtures', 'files', 'test.txt')
        unless File.exist?(file)
          File.write(file, 'This is a test file')
        end
        
        image.file.attach(
          io: File.open(file),
          filename: 'test.txt',
          content_type: 'text/plain'
        )
      end
    end

    trait :with_small_dimensions do
      after(:build) do |image|
        file = Rails.root.join('spec', 'fixtures', 'files', 'small_image.jpg')
        unless File.exist?(file)
          require 'mini_magick'
          MiniMagick::Tool::Convert.new do |convert|
            convert << '-size' << '100x100'
            convert << 'xc:white'
            convert << file.to_s
          end
        end
        
        image.file.attach(
          io: File.open(file),
          filename: 'small_image.jpg',
          content_type: 'image/jpeg'
        )
      end
    end
  end
end 