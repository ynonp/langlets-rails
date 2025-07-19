Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: "users/sessions",
    registrations: "users/registrations",
    omniauth_callbacks: 'users/omniauth_callbacks'
  }
  get "home/privacy"
  get "home/terms"
  root "courses#index"
  get "landing_page/index"
  resources :lessons, only: [:show] do
    member do
      get :finish
    end
  end
  resources :courses, only: [:show, :index, :new, :create] do
    member do
      post :like
      delete :unlike
    end
  end
  get '/azure_token', to: 'azure_speech#token'
  get "activities/index"
  get "activities/show"
  
  resources :progress, only: [:create]
  post '/sync_local_xp', to: 'progress#sync_local_xp'
  post '/log', to: 'progress#log'
  
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
