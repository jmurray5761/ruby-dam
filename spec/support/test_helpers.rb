module TestHelpers
  def create_test_image(byte_size: 1.megabyte)
    file = Tempfile.new(['test_image', '.jpg'])
    file.binmode
    
    MiniMagick::Tool::Convert.new do |convert|
      convert.size '800x600'
      convert.xc 'white'
      convert << file.path
    end

    # Ensure the file is of the specified size
    file.rewind
    current_size = file.size
    if current_size < byte_size
      # Pad the file with zeros to reach the desired size
      file.write("\0" * (byte_size - current_size))
    end
    
    file.rewind
    { io: file, filename: 'test_image.jpg', content_type: 'image/jpeg' }
  end

  def create_test_file(content_type: 'text/plain')
    file = Tempfile.new(['test_file', '.txt'])
    file.write('Test file content')
    file.rewind
    { io: file, filename: 'test_file.txt', content_type: content_type }
  end
end

RSpec.configure do |config|
  config.include TestHelpers
end 