require 'rails_helper'

RSpec.describe ImagesController, type: :controller do
  let(:valid_attributes) do
    {
      name: "Test Image",
      description: "Test Description",
      file: fixture_file_upload('spec/fixtures/files/test_image.jpg', 'image/jpeg')
    }
  end

  let(:invalid_attributes) do
    {
      name: nil,
      description: nil,
      file: nil
    }
  end

  describe 'GET #index' do
    it 'returns a success response' do
      get :index
      expect(response).to be_successful
    end
  end

  describe 'GET #show' do
    it 'returns a success response' do
      image = create(:image, :with_file)
      get :show, params: { id: image.to_param }
      expect(response).to be_successful
    end
  end

  describe 'GET #new' do
    it 'returns a success response' do
      get :new
      expect(response).to be_successful
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
    end

    context 'with invalid params' do
      it 'returns a success response (i.e. to display the new template)' do
        post :create, params: { image: invalid_attributes }
        expect(response).to be_successful
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