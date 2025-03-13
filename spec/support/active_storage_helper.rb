module ActiveStorageHelper
  def create_test_image(metadata: nil, content_type: 'image/png', byte_size: 1.megabyte)
    file = fixture_file_upload('spec/fixtures/files/test_image.jpg', content_type)
    
    # Create the blob
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file.open,
      filename: file.original_filename,
      content_type: content_type,
      metadata: metadata || { 'width' => 300, 'height' => 300 }
    )

    # Update blob attributes
    blob.update_column(:byte_size, byte_size)

    # Return the blob key for attachment
    blob.signed_id
  end

  def create_test_file(content_type: 'text/plain', byte_size: 1.megabyte)
    file = fixture_file_upload('spec/fixtures/files/test_image.jpg', 'image/jpeg')
    
    # Create the blob with the specified content type
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file.open,
      filename: file.original_filename,
      content_type: content_type,
      metadata: {}
    )

    # Force update the content type
    blob.update_column(:content_type, content_type)
    blob.update_column(:byte_size, byte_size)

    # Return the blob key for attachment
    blob.signed_id
  end
end

RSpec.configure do |config|
  config.include ActiveStorageHelper
end 