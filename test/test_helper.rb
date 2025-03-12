ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "mocha/minitest"

class ActiveSupport::TestCase
  # Disable parallel testing
  parallelize(workers: 1)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...
  include ActionDispatch::TestProcess::FixtureFile
  include ActiveJob::TestHelper
  include Mocha::API

  # Configure ActiveJob and ActiveStorage for testing
  setup do
    ActiveJob::Base.queue_adapter = :test
    ActiveStorage::Current.url_options = { host: "localhost:3000" }
    Rails.application.routes.default_url_options[:host] = "localhost:3000"
  end

  # Clean up uploaded files and reset jobs
  teardown do
    FileUtils.rm_rf(ActiveStorage::Blob.service.root)
    clear_enqueued_jobs
    clear_performed_jobs
  end

  def create_test_image(metadata: nil, content_type: 'image/png', byte_size: 1.megabyte)
    file = fixture_file_upload('test_image.png', content_type)
    
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
    file = fixture_file_upload('test_image.png', 'image/png')
    
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
