require 'rails_helper'

RSpec.describe ImagesController, type: :controller do
  let(:valid_attributes) do
    {
      name: "Test Image",
      description: "A test image description",
      file: fixture_file_upload('spec/fixtures/files/test_image.jpg', 'image/jpeg')
    }
  end

  let(:invalid_attributes) do
    {
      name: '',
      description: '',
      file: nil
    }
  end

  let(:invalid_dimensions_attributes) do
    {
      name: "Invalid Dimensions Image",
      description: "An image with invalid dimensions",
      file: Rack::Test::UploadedFile.new(
        StringIO.new('GIF89a\x01\x00\x01\x00\x80\x00\x00\xff\xff\xff\x00\x00\x00!\xf9\x04\x01\x00\x00\x00\x00,\x00\x00\x00\x00\x01\x00\x01\x00\x00\x02\x02D\x01\x00;'),
        'image/gif',
        true,
        original_filename: 'small_image.gif'
      )
    }
  end

  let(:oversized_file_attributes) do
    file_content = '0' * 6.megabytes
    file = Rack::Test::UploadedFile.new(
      StringIO.new(file_content),
      'image/jpeg',
      true,
      original_filename: 'large_image.jpg'
    )
    {
      name: 'Test Image',
      description: 'Test Description',
      file: file
    }
  end

  let(:malformed_file_attributes) do
    {
      name: "Malformed Image",
      description: "A malformed image file",
      file: Rack::Test::UploadedFile.new(
        StringIO.new('Not a real image file content'),
        'image/jpeg',
        true,
        original_filename: 'malformed.jpg'
      )
    }
  end

  describe 'GET #index' do
    it 'returns a success response' do
      get :index
      expect(response).to be_successful
      expect(response).to have_http_status(:ok)
    end

    it 'assigns all images as @images' do
      image1 = create(:image, :with_file)
      image2 = create(:image, :with_file)
      get :index
      expect(assigns(:images)).to match_array([image1, image2])
    end

    it 'renders the index template' do
      get :index
      expect(response).to render_template(:index)
    end
  end

  describe 'GET #show' do
    let(:image) { create(:image, :with_file) }

    it 'returns a success response' do
      get :show, params: { id: image.to_param }
      expect(response).to be_successful
      expect(response).to have_http_status(:ok)
    end

    it 'assigns the requested image as @image' do
      get :show, params: { id: image.to_param }
      expect(assigns(:image)).to eq(image)
    end

    it 'renders the show template' do
      get :show, params: { id: image.to_param }
      expect(response).to render_template(:show)
    end

    context 'with non-existent image' do
      it 'redirects to index with not found message' do
        get :show, params: { id: 999 }
        expect(response).to redirect_to(images_url)
        expect(flash[:alert]).to eq('Image not found.')
      end

      it 'returns not found status in JSON format' do
        get :show, params: { id: 999 }, format: :json
        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)).to include(
          "status" => "error",
          "message" => "Image not found."
        )
      end
    end
  end

  describe 'GET #new' do
    it 'returns a success response' do
      get :new
      expect(response).to be_successful
      expect(response).to have_http_status(:ok)
    end

    it 'assigns a new image as @image' do
      get :new
      expect(assigns(:image)).to be_a_new(Image)
    end

    it 'renders the new template' do
      get :new
      expect(response).to render_template(:new)
    end
  end

  describe 'GET #edit' do
    it 'returns a success response' do
      image = create(:image, :with_file)
      get :edit, params: { id: image.to_param }
      expect(response).to be_successful
    end
  end

  describe 'POST #create' do
    context 'with valid parameters' do
      before do
        # Mock the dimension validation for test environment
        allow_any_instance_of(Image).to receive(:get_dimensions).and_return({ width: 200, height: 200 })
      end

      it 'creates a new Image' do
        expect {
          post :create, params: { image: valid_attributes }
        }.to change(Image, :count).by(1)
      end

      it 'assigns a newly created image as @image' do
        post :create, params: { image: valid_attributes }
        expect(assigns(:image)).to be_a(Image)
        expect(assigns(:image)).to be_persisted
      end

      it 'redirects to the created image' do
        post :create, params: { image: valid_attributes }
        expect(response).to redirect_to(Image.last)
      end

      it 'attaches the file' do
        post :create, params: { image: valid_attributes }
        expect(Image.last.file).to be_attached
      end
    end

    context 'with invalid file type' do
      let(:invalid_file_type_attributes) do
        {
          name: "Test Image",
          description: "Test Description",
          file: fixture_file_upload('spec/fixtures/files/invalid.txt', 'text/plain')
        }
      end

      it 'does not create a new Image' do
        expect {
          post :create, params: { image: invalid_file_type_attributes }
        }.not_to change(Image, :count)
      end

      it 'returns unprocessable entity status' do
        post :create, params: { image: invalid_file_type_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'includes error message about invalid file type' do
        post :create, params: { image: invalid_file_type_attributes }
        expect(assigns(:image).errors[:file]).to include('must be a PNG, JPEG, or GIF')
      end
    end

    context 'with file size exceeding limit' do
      let(:oversized_file_attributes) do
        file_content = '0' * 6.megabytes
        file = Rack::Test::UploadedFile.new(
          StringIO.new(file_content),
          'image/jpeg',
          true,
          original_filename: 'large_image.jpg'
        )
        {
          name: 'Test Image',
          description: 'Test Description',
          file: file
        }
      end

      it 'does not create a new Image' do
        expect {
          post :create, params: { image: oversized_file_attributes }
        }.not_to change(Image, :count)
      end

      it 'returns unprocessable entity status' do
        post :create, params: { image: oversized_file_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'includes error message about file size' do
        post :create, params: { image: oversized_file_attributes }
        expect(assigns(:image).errors[:file]).to include('The file size is too large')
      end
    end

    context 'with malformed image file' do
      before do
        allow_any_instance_of(Image).to receive(:validate_file_type).and_raise(ActiveStorage::IntegrityError.new("Invalid file format"))
      end

      it 'does not create a new Image' do
        expect {
          post :create, params: { image: malformed_file_attributes }
        }.not_to change(Image, :count)
      end

      it 'returns unprocessable entity status' do
        post :create, params: { image: malformed_file_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'includes error about invalid file format' do
        post :create, params: { image: malformed_file_attributes }
        expect(assigns(:image).errors[:file]).to include("File upload failed. Please try again.")
      end
    end

    context "with timeout during upload" do
      before do
        allow_any_instance_of(Image).to receive(:save).and_raise(Timeout::Error.new("Upload timed out"))
      end

      it "handles timeout error" do
        post :create, params: { image: valid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(assigns(:image).errors[:base]).to include("Upload timed out, please try again")
      end
    end

    context "with disk full error" do
      before do
        allow_any_instance_of(Image).to receive(:save).and_raise(StandardError.new("Disk is full"))
      end

      it "handles disk full error" do
        post :create, params: { image: valid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(assigns(:image).errors[:base]).to include("File could not be uploaded: storage error")
      end
    end

    context 'with concurrent upload' do
      before do
        allow_any_instance_of(Image).to receive(:save).and_raise(ActiveRecord::StaleObjectError)
      end

      it 'handles race condition' do
        post :create, params: { image: valid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(assigns(:image).errors[:base]).to include("Upload conflict detected, please try again")
      end
    end

    context 'with invalid dimensions' do
      it 'does not create a new Image' do
        expect {
          post :create, params: { image: invalid_dimensions_attributes }
        }.not_to change(Image, :count)
      end

      it 'returns unprocessable entity status' do
        post :create, params: { image: invalid_dimensions_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'includes error about invalid dimensions' do
        post :create, params: { image: invalid_dimensions_attributes }
        expect(assigns(:image).errors[:dimensions]).to include("must be at least 100x100 pixels")
      end
    end

    # Add JSON API response tests
    context "with JSON format" do
      render_views

      before do
        # Mock the dimension validation for test environment
        allow_any_instance_of(Image).to receive(:get_dimensions).and_return({ width: 200, height: 200 })
      end

      it "returns JSON response for successful creation" do
        post :create, params: { image: valid_attributes, format: :json }
        expect(response.content_type).to include('application/json')
        expect(JSON.parse(response.body)).to include(
          'status' => 'success',
          'message' => 'Image was successfully uploaded and processed.'
        )
      end

      it "returns JSON response for validation errors" do
        post :create, params: { image: invalid_attributes, format: :json }
        expect(response.content_type).to include('application/json')
        json_response = JSON.parse(response.body)
        expect(json_response['status']).to eq('error')
        expect(json_response).to have_key('errors')
      end
    end
  end

  describe 'PUT #update' do
    context 'with valid params' do
      let(:new_attributes) do
        {
          name: "Updated Image",
          description: "Updated Description"
        }
      end

      let(:image) { create(:image, :with_file) }

      before do
        allow_any_instance_of(Image).to receive(:get_dimensions).and_return({ width: 200, height: 200 })
      end

      it 'updates the requested image' do
        put :update, params: { id: image.to_param, image: new_attributes }
        image.reload
        expect(image.name).to eq("Updated Image")
        expect(image.description).to eq("Updated Description")
      end

      it 'redirects to the image' do
        put :update, params: { id: image.to_param, image: valid_attributes }
        expect(response).to redirect_to(image)
      end
    end

    context 'with invalid params' do
      let(:image) { create(:image, :with_file) }

      it 'returns unprocessable entity status' do
        put :update, params: { id: image.to_param, image: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the requested image' do
      image = create(:image, :with_file)
      expect {
        delete :destroy, params: { id: image.to_param }
      }.to change(Image, :count).by(-1)
    end

    it 'redirects to the images list' do
      image = create(:image, :with_file)
      delete :destroy, params: { id: image.to_param }
      expect(response).to redirect_to(images_url)
    end
  end
end 