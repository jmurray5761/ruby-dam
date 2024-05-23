require "test_helper"

class ImageTest < ActiveSupport::TestCase
  test "should not save an image without contents" do
    image = Image.new
    assert_not image.save, "Saved the image without a contents"
  end

end
