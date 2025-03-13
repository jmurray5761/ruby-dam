# Ruby Digital Asset Manager (DAM)

A Ruby on Rails application for managing digital assets, with a focus on image management and processing.

## Testing

### Setup and Running Tests

1. Install dependencies:
```bash
bundle install
```

2. Set up the test database:
```bash
bundle exec rails db:test:prepare
```

3. Run the test suite:
```bash
bundle exec rspec
```

### Test Structure

The project uses RSpec for testing with the following organization:

- `spec/models/` - Model specs for testing business logic and validations
- `spec/controllers/` - Controller specs for testing HTTP endpoints
- `spec/support/` - Shared test helpers and configurations
- `spec/factories/` - Factory Bot factories for test data generation

### Testing Patterns and Conventions

1. **Factory Bot Patterns**
   - Use traits for different test scenarios (e.g., `:with_file`, `:with_large_file`)
   - Dynamic file creation in factories to ensure test files exist
   - Use meaningful factory names and traits

2. **Image Testing**
   - Test fixtures are automatically generated using MiniMagick
   - Standard test image is 200x200 pixels
   - Small test image is 100x100 pixels
   - Large test image is 1000x1000 pixels

3. **Validation Testing**
   - Image dimension validation is skipped in test environment for performance
   - File type validation uses standard image formats (PNG, JPEG, GIF)
   - File size validation limits files to 10MB

4. **Active Storage Testing**
   - Uses in-memory storage for tests
   - Cleans up test files after each example
   - Handles file attachments in a test-friendly way

5. **Job Testing**
   - Uses ActiveJob test adapter
   - Verifies job enqueuing without processing
   - Supports both immediate and delayed job testing

### Test Helpers

1. **Active Storage Helper**
   - `create_test_image` - Creates and attaches a test image
   - `create_test_file` - Creates and attaches a non-image file
   - Supports custom metadata, content types, and file sizes

2. **Factory Traits**
   - `:with_file` - Attaches a standard test image
   - `:with_generated_metadata` - Sets up AI-generated metadata
   - `:with_large_file` - Creates oversized test files
   - `:with_invalid_file_type` - Creates invalid file types
   - `:with_small_dimensions` - Creates undersized images

### Best Practices

1. **File Management**
   - Always clean up test files after use
   - Use `after(:each)` hooks for cleanup
   - Store test files in `spec/fixtures/files/`

2. **Test Data**
   - Use factories instead of fixtures
   - Keep test data minimal and focused
   - Use meaningful test data names

3. **Mocking and Stubbing**
   - Mock external services (OpenAI, etc.)
   - Stub file operations when possible
   - Use RSpec's mocking features

4. **Performance**
   - Skip heavy validations in test environment
   - Use transactional fixtures
   - Clean up test data properly

### Debugging Tests

1. Run specific tests:
```bash
bundle exec rspec spec/path/to/file_spec.rb:line_number
```

2. Use logging in tests:
```ruby
Rails.logger.debug("Debug information")
```

3. Use RSpec formatting options:
```bash
bundle exec rspec --format documentation
```

### Continuous Integration

Tests are automatically run in GitHub Actions:
- On push to main branch
- On pull requests
- Test results are uploaded as artifacts

For more detailed information about specific test cases, refer to the test files in the `spec/` directory.
