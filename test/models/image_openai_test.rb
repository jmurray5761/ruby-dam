require "test_helper"

class ImageOpenAITest < ActiveSupport::TestCase
  setup do
    @image = Image.new
    @image.file.attach(create_test_image)
    @image.generate_name_and_description = true
  end

  test "should generate name and description when flag is set" do
    OpenAI::Client.any_instance.expects(:chat).returns({
      'choices' => [{
        'message' => {
          'content' => "Name: Beautiful White Square\nDescription: A simple white square image with clean edges."
        }
      }]
    })

    assert @image.save
    assert_equal "Beautiful White Square", @image.name
    assert_equal "A simple white square image with clean edges.", @image.description
  end

  test "should handle OpenAI API errors gracefully" do
    OpenAI::Client.any_instance.expects(:chat).raises(OpenAI::Error.new("API error"))
    
    assert_not @image.save
    assert_includes @image.errors[:base], "OpenAI API call failed: API error"
  end

  test "should handle malformed OpenAI response" do
    OpenAI::Client.any_instance.expects(:chat).returns({
      'choices' => [{
        'message' => {
          'content' => "Invalid format response"
        }
      }]
    })

    assert_not @image.save
    assert_includes @image.errors[:base], "Failed to parse OpenAI response"
  end

  test "should handle image encoding errors" do
    @image.file.expects(:download).raises(StandardError.new("Failed to download"))
    
    assert_not @image.save
    assert_includes @image.errors[:base], "Failed to encode image: Failed to download"
  end
end 