require "test_helper"

class ImageTest < ActiveSupport::TestCase
  def setup
    @image = Image.new(
      name: "Test Image",
      description: "A test image description",
      generate_name_and_description: false
    )
    @image.file.attach(create_test_image)
  end

  test "should not save an image without name and description" do
    image = Image.new
    image.file.attach(create_test_image)
    assert_not image.save
    assert_includes image.errors[:name], "can't be blank"
    assert_includes image.errors[:description], "can't be blank"
  end

  test "should save an image with name and description" do
    assert @image.save
  end

  test "should require file attachment" do
    image = Image.new(name: "Test Image", description: "Test Description")
    assert_not image.valid?, "Saved the image without a file"
    assert_includes image.errors[:file], "can't be blank"
  end

  test "should validate file size" do
    @image.file.attach(create_test_image(byte_size: 11.megabytes))
    assert_not @image.save
    assert_includes @image.errors[:file], 'The file size is too large'
  end

  test "should validate file type" do
    @image.file.attach(create_test_file(content_type: 'text/plain'))
    assert_not @image.save
    assert_includes @image.errors[:file], 'must be a PNG, JPEG, or GIF'
  end

  test "should validate image dimensions" do
    @image.file.attach(create_test_image(metadata: { 'width' => 100, 'height' => 100 }))
    assert_not @image.save
    assert_includes @image.errors[:file], 'dimensions must be at least 200x200 pixels'
  end

  test "should enqueue image processing after create" do
    @image.generate_name_and_description = true
    assert_enqueued_with(job: ImageProcessingJob) do
      @image.save
    end
  end

  test "should not enqueue image processing when flag is false" do
    @image.generate_name_and_description = false
    perform_enqueued_jobs do
      @image.save
    end
    assert_no_enqueued_jobs
  end

  test "should handle file attachment errors" do
    @image.file.attach(create_test_image)
    @image.file.stubs(:metadata).raises(StandardError.new("Failed to read metadata"))
    assert_not @image.save
    assert_includes @image.errors[:file], "Error checking dimensions: Failed to read metadata"
  end

  test "should set default generate flag to false" do
    image = Image.new
    image.valid?
    assert_equal false, image.generate_name_and_description
  end
end
