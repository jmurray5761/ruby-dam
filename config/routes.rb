Rails.application.routes.draw do
  root "images#index"
  resources :images do
    collection do
      get 'search', to: 'images#search'
      post 'search_by_image', to: 'images#search_by_image'
      post 'batch_upload', to: 'images#batch_upload'
    end
  end

  resources :directory_browser, only: [:index]
end
