RSpec.shared_examples 'a valid image' do |image|
  it 'is valid' do
    expect(image).to be_valid
  end

  it 'has a name' do
    expect(image.name).to be_present
  end

  it 'has a description' do
    expect(image.description).to be_present
  end

  it 'has an attached file' do
    expect(image.file).to be_attached
  end
end

RSpec.shared_examples 'an invalid image' do |image, error_messages|
  it 'is not valid' do
    expect(image).not_to be_valid
  end

  it 'has the expected error messages' do
    error_messages.each do |attribute, message|
      expect(image.errors[attribute]).to include(message)
    end
  end
end

RSpec.shared_examples 'a file upload validation' do |image, file_type, error_message|
  it "validates #{file_type} files" do
    image.file.attach(create_test_file(content_type: file_type))
    expect(image).not_to be_valid
    expect(image.errors[:file]).to include(error_message)
  end
end 