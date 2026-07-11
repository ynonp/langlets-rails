Rails.application.routes.draw do
  # OAuth 2.1 provider for AI agents (MCP clients, CLI). Token management UI
  # lives at settings/connections instead of Doorkeeper's authorized_applications.
  use_doorkeeper do
    skip_controllers :authorized_applications
  end
  post "/oauth/register", to: "oauth/registrations#create"
  get "/.well-known/oauth-authorization-server", to: "well_known#oauth_authorization_server"
  get "/.well-known/oauth-protected-resource", to: "well_known#oauth_protected_resource"
  get "/.well-known/oauth-protected-resource/mcp", to: "well_known#oauth_protected_resource"

  match "/mcp", to: "mcp#handle", via: [ :get, :post, :delete ]

  namespace :api do
    namespace :v1 do
      get "vocabulary", to: "vocabulary#index"
      get "courses", to: "courses#index"
    end
  end

  namespace :settings do
    resources :connections, only: [ :index, :destroy ] do
      collection do
        delete :revoke_application
      end
    end
  end

  devise_for :users, controllers: {
    sessions: "users/sessions",
    registrations: "users/registrations",
    omniauth_callbacks: "users/omniauth_callbacks"
  }

  devise_scope :user do
    get "users/auth/native_success", to: "users/omniauth_callbacks#native_success"
    post "users/auth/native_google", to: "users/omniauth_callbacks#native_google"
    post "users/auth/native_apple", to: "users/omniauth_callbacks#native_apple"
  end
  resources :create_song_progress, only: [ :show ]
  get "home/privacy"
  get "home/terms"
  get "onboarding/language", to: "onboarding#language", as: :onboarding_language
  root "courses#index"
  get "/sitemap.xml", to: "sitemaps#show", defaults: { format: :xml }
  get "landing_page/index"
  resources :courses, only: [ :show, :index, :new, :create ] do
    member do
      post :mark_done
      post :reset_progress
    end
    resources :learning_paths, only: [ :index, :create, :destroy ], controller: "course_learning_paths"
    resources :lessons, only: [ :show ] do
      member do
        get :finish
      end
    end
  end
  resources :import_courses, only: [ :new, :create ]
  resources :resync_timestamps, only: [ :new, :create ]
  get "courses/:course_slug/full-player", to: "full_player#show", as: :course_full_player
  resources :learning_paths, only: [ :show, :destroy ] do
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

  # Persist the user's light/dark theme choice.
  patch "preferences/theme", to: "preferences#update", as: :theme_preference

  # Persist the watch-video activity toggles (translation / karaoke).
  patch "preferences/watch_video", to: "preferences#watch_video", as: :watch_video_preferences

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
