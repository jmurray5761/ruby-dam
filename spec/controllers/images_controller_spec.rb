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
    file_content = '0' * 11.megabytes # Larger than MAX_FILE_SIZE (10MB)
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
      it 'redirects to index with error message' do
        get :show, params: { id: 'nonexistent' }
        expect(response).to redirect_to(images_path)
        expect(flash[:alert]).to eq('Image not found.')
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
    let(:image) { create(:image, :with_file) }

    it 'returns a success response' do
      get :edit, params: { id: image.to_param }
      expect(response).to be_successful
      expect(response).to have_http_status(:ok)
    end

    it 'assigns the requested image as @image' do
      get :edit, params: { id: image.to_param }
      expect(assigns(:image)).to eq(image)
    end

    it 'renders the edit template' do
      get :edit, params: { id: image.to_param }
      expect(response).to render_template(:edit)
    end
  end

  describe 'POST #create' do
    let(:errors_double) do
      double('errors',
        add: true,
        clear: nil,
        messages: { file: ['The file size is too large'] },
        empty?: false,
        full_messages: ['The file size is too large']
      )
    end

    context 'with valid params' do
      it 'creates a new Image' do
        expect {
          post :create, params: { image: valid_attributes }
        }.to change(Image, :count).by(1)
      end

      it 'redirects to the created image' do
        post :create, params: { image: valid_attributes }
        expect(response).to redirect_to(Image.last)
      end

      it 'sets a success notice' do
        post :create, params: { image: valid_attributes }
        expect(flash[:notice]).to eq('Image was successfully uploaded.')
      end
    end

    context 'with invalid params' do
      it 'returns a success response (i.e. to display the new template)' do
        post :create, params: { image: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 're-renders the new template' do
        post :create, params: { image: invalid_attributes }
        expect(response).to render_template(:new)
      end

      it 'assigns a newly created but unsaved image as @image' do
        post :create, params: { image: invalid_attributes }
        expect(assigns(:image)).to be_a_new(Image)
      end
    end

    context 'with oversized file' do
      before do
        allow_any_instance_of(Image).to receive(:validate_file_size).and_return(false)
        allow_any_instance_of(Image).to receive(:errors).and_return(
          double('errors',
            add: true,
            clear: nil,
            messages: { file: ['The file size is too large'] },
            empty?: false,
            full_messages: ['The file size is too large']
          )
        )
      end

      it 'does not create a new image' do
        expect {
          post :create, params: { image: valid_attributes }
        }.not_to change(Image, :count)
      end

      it 'returns unprocessable entity status' do
        post :create, params: { image: valid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'renders the new template' do
        post :create, params: { image: valid_attributes }
        expect(response).to render_template(:new)
      end
    end

    context 'with invalid dimensions' do
      before do
        allow_any_instance_of(Image).to receive(:validate_dimensions).and_return(false)
        allow_any_instance_of(Image).to receive(:errors).and_return(
          double('errors',
            add: true,
            clear: nil,
            messages: { dimensions: ['must be at least 100x100 pixels'] },
            empty?: false,
            full_messages: ['Dimensions must be at least 100x100 pixels']
          )
        )
      end

      it 'does not create a new image' do
        expect {
          post :create, params: { image: valid_attributes }
        }.not_to change(Image, :count)
      end

      it 'returns unprocessable entity status' do
        post :create, params: { image: valid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'renders the new template' do
        post :create, params: { image: valid_attributes }
        expect(response).to render_template(:new)
      end
    end

    context 'with malformed file' do
      before do
        allow_any_instance_of(Image).to receive(:validate_file_type).and_return(false)
        allow_any_instance_of(Image).to receive(:errors).and_return(
          double('errors',
            add: true,
            clear: nil,
            messages: { file: ['must be a PNG, JPEG, or GIF'] },
            empty?: false,
            full_messages: ['File must be a PNG, JPEG, or GIF']
          )
        )
      end

      it 'does not create a new image' do
        expect {
          post :create, params: { image: valid_attributes }
        }.not_to change(Image, :count)
      end

      it 'returns unprocessable entity status' do
        post :create, params: { image: valid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'renders the new template' do
        post :create, params: { image: valid_attributes }
        expect(response).to render_template(:new)
      end
    end
  end

  describe 'PUT #update' do
    let(:image) { create(:image, :with_file) }
    let(:new_attributes) do
      {
        name: 'Updated Image',
        description: 'Updated description'
      }
    end

    context 'with valid params' do
      it 'updates the requested image' do
        put :update, params: { id: image.to_param, image: new_attributes }
        image.reload
        expect(image.name).to eq('Updated Image')
        expect(image.description).to eq('Updated description')
      end

      it 'redirects to the image' do
        put :update, params: { id: image.to_param, image: new_attributes }
        expect(response).to redirect_to(image)
      end

      it 'sets a success notice' do
        put :update, params: { id: image.to_param, image: new_attributes }
        expect(flash[:notice]).to eq('Image was successfully updated.')
      end
    end

    context 'with invalid params' do
      it 'returns a success response (i.e. to display the edit template)' do
        put :update, params: { id: image.to_param, image: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 're-renders the edit template' do
        put :update, params: { id: image.to_param, image: invalid_attributes }
        expect(response).to render_template(:edit)
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:image) { create(:image, :with_file) }

    it 'destroys the requested image' do
      expect {
        delete :destroy, params: { id: image.to_param }
      }.to change(Image, :count).by(-1)
    end

    it 'redirects to the images list' do
      delete :destroy, params: { id: image.to_param }
      expect(response).to redirect_to(images_url)
    end

    it 'sets a success notice' do
      delete :destroy, params: { id: image.to_param }
      expect(flash[:notice]).to eq('Image was successfully deleted.')
    end
  end
end 