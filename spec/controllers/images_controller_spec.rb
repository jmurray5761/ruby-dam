require 'rails_helper'

RSpec.describe ImagesController, type: :controller do
  let(:valid_attributes) do
    file_content = '0' * 2.kilobytes
    file = Rack::Test::UploadedFile.new(
      StringIO.new(file_content),
      'image/jpeg',
      true,
      original_filename: 'test_image.jpg'
    )
    {
      name: 'Test Image',
      description: 'Test Description',
      file: file
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
    file_content = '0' * 500
    file = Rack::Test::UploadedFile.new(
      StringIO.new(file_content),
      'image/jpeg',
      true,
      original_filename: 'small_image.jpg'
    )
    {
      name: 'Test Image',
      description: 'Test Description',
      file: file
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
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          get :show, params: { id: 'non-existent' }
        }.to raise_error(ActiveRecord::RecordNotFound)
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
        expect(flash[:notice]).to be_present
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
        {
          name: "Test Image",
          description: "Test Description",
          file: Rack::Test::UploadedFile.new(StringIO.new('0' * 6.megabytes), 'image/jpeg', true, original_filename: 'large_image.jpg')
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
        expect(assigns(:image).errors[:file]).to include('is too large')
      end
    end

    context 'with invalid image dimensions' do
      let(:invalid_dimensions_attributes) do
        # Create a small JPEG image in memory
        small_image = StringIO.new
        small_image.write([
          0xFF, 0xD8,                     # SOI marker
          0xFF, 0xE0,                     # APP0 marker
          0x00, 0x10,                     # Length of APP0 segment
          0x4A, 0x46, 0x49, 0x46, 0x00,  # "JFIF" marker
          0x01, 0x01,                     # Version
          0x00,                           # Units
          0x00, 0x01,                     # X density
          0x00, 0x01,                     # Y density
          0x00, 0x00                      # Thumbnail
        ].pack('C*'))
        small_image.rewind

        {
          name: "Test Image",
          description: "Test Description",
          file: Rack::Test::UploadedFile.new(small_image, 'image/jpeg', true, original_filename: 'small_image.jpg')
        }
      end

      it 'does not create a new Image' do
        expect {
          post :create, params: { image: invalid_dimensions_attributes }
        }.not_to change(Image, :count)
      end

      it 'returns unprocessable entity status' do
        post :create, params: { image: invalid_dimensions_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'includes error message about invalid dimensions' do
        post :create, params: { image: invalid_dimensions_attributes }
        expect(assigns(:image).errors[:file]).to include('dimensions must be at least 100x100 pixels')
      end
    end

    context 'with invalid parameters' do
      it 'does not create a new Image' do
        expect {
          post :create, params: { image: invalid_attributes }
        }.not_to change(Image, :count)
      end

      it 'assigns a newly created but unsaved image as @image' do
        post :create, params: { image: invalid_attributes }
        expect(assigns(:image)).to be_a_new(Image)
      end

      it 'returns unprocessable entity status' do
        post :create, params: { image: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 're-renders the new template' do
        post :create, params: { image: invalid_attributes }
        expect(response).to render_template(:new)
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

      it 'updates the requested image' do
        image = create(:image, :with_file)
        put :update, params: { id: image.to_param, image: new_attributes }
        image.reload
        expect(image.name).to eq("Updated Image")
        expect(image.description).to eq("Updated Description")
      end

      it 'redirects to the image' do
        image = create(:image, :with_file)
        put :update, params: { id: image.to_param, image: valid_attributes }
        expect(response).to redirect_to(image)
      end
    end

    context 'with invalid params' do
      it 'returns a success response (i.e. to display the edit template)' do
        image = create(:image, :with_file)
        put :update, params: { id: image.to_param, image: invalid_attributes }
        expect(response).to be_successful
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