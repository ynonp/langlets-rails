Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: "users/sessions",
    registrations: "users/registrations",
    omniauth_callbacks: "users/omniauth_callbacks"
  }

  devise_scope :user do
    get "users/auth/native_success", to: "users/omniauth_callbacks#native_success"
    post "users/auth/native_google", to: "users/omniauth_callbacks#native_google"
  end
  resources :create_song_progress, only: [ :show ]
  get "home/privacy"
  get "home/terms"
  get "onboarding/language", to: "onboarding#language", as: :onboarding_language
  root "courses#index"
  get "landing_page/index"
  resources :courses, only: [ :show, :index, :new, :create ] do
    member do
      post :mark_done
      post :reset_progress
    end
    resources :lessons, only: [ :show ] do
      member do
        get :finish
      end
    end
  end
  resources :import_courses, only: [ :new, :create ]
  get "courses/:course_slug/full-player", to: "full_player#show", as: :course_full_player
  resources :learning_paths, only: [ :show ] do
    member do
      get :search_courses, defaults: { format: :json }
    end
  end
  get "/azure_token", to: "azure_speech#token"
  get "activities/index"
  get "activities/show"

  resources :progress, only: [ :create ] do
    collection do
      post :toggle_lesson
    end
  end
  post "/sync_local_xp", to: "progress#sync_local_xp"
  post "/log", to: "progress#log"

  resources :token_translation_users, only: [ :create, :destroy ]

  resources :review_lessons, only: [ :create, :show ] do
    member do
      get :finish
    end
  end

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
