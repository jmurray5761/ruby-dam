FactoryBot.define do
  factory :image do
    name { Faker::Lorem.words(number: 4).join(' ') }
    description { Faker::Lorem.paragraph }
    generate_name_and_description { false }

    trait :with_file do
      after(:build) do |image|
        # Create a test image file
        file = Rails.root.join('spec', 'fixtures', 'files', 'test_image.jpg')
        unless File.exist?(file)
          require 'mini_magick'
          MiniMagick::Tool::Convert.new do |convert|
            convert << '-size' << '200x200'
            convert << 'xc:white'
            convert << file.to_s
          end
        end
        
        image.file.attach(
          io: File.open(file),
          filename: 'test_image.jpg',
          content_type: 'image/jpeg'
        )
      end
    end

    trait :with_generated_metadata do
      generate_name_and_description { true }
      with_file
    end

    trait :with_large_file do
      after(:build) do |image|
        file = Rails.root.join('spec', 'fixtures', 'files', 'large_image.jpg')
        unless File.exist?(file)
          require 'mini_magick'
          MiniMagick::Tool::Convert.new do |convert|
            convert << '-size' << '1000x1000'
            convert << 'xc:white'
            convert << file.to_s
          end
        end
        
        image.file.attach(
          io: File.open(file),
          filename: 'large_image.jpg',
          content_type: 'image/jpeg'
        )
      end
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