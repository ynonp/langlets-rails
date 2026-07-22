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

  # Progress patches from the Create Song pipeline service (HMAC-signed; see
  # pipeline/README.md for the protocol).
  post "/pipeline_callbacks/:id", to: "pipeline_callbacks#update", as: :pipeline_callback

  namespace :api do
    namespace :v1 do
      get "vocabulary", to: "vocabulary#index"
      get "courses", to: "courses#index"

      # Used by the iOS app and its share extension (bearer auth — an extension
      # can't read the host app's session cookie).
      resources :import_requests, only: [ :index, :create ]
      resource :credits, only: [ :show ]
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
  # Hotwire Native path configuration for the iOS app (see ConfigurationsController).
  get "/configurations/ios_v1", to: "configurations#ios_v1"

  # The langlets. app screens. Most are shown only inside the native shell;
  # Queue and Add Video are also linked from the authenticated web UI.
  namespace :app do
    root to: "home#index", as: :home
    # controller: pinned — a singular `resource` would otherwise look for
    # App::LibrariesController.
    resource :library, only: [ :show ], controller: "library"
    resources :started_courses, only: [ :index ]
    resources :enrollments, only: [ :create ]
    resources :import_requests, only: [ :index, :new, :create, :destroy ] do
      member do
        post :retry
      end
      collection do
        # Preview for the Add Video sheet: metadata + duplicate + price, no charge.
        get :resolve
      end
    end
    resource :credits, only: [ :show ]
    # The authenticated web view bootstraps a narrowly scoped bearer token into
    # the native app's shared Keychain for use by the share extension.
    resource :native_token, only: [ :create ]
    # The iOS app posts its APNs token here via bridge--push.
    resources :device_tokens, only: [ :create ]
  end

  get "home/privacy"
  get "home/terms"
  get "support", to: "home#support"
  get "onboarding/welcome", to: "onboarding#welcome", as: :onboarding_welcome
  get "onboarding/language", to: "onboarding#language", as: :onboarding_language
  get "profile", to: "profile#show", as: :profile
  root "courses#index"
  get "/sitemap.xml", to: "sitemaps#show", defaults: { format: :xml }
  get "landing_page/index"
  resources :courses, only: [ :show, :index, :new, :create ] do
    member do
      post :mark_done
      post :reset_progress
    end
    resources :playlists, only: [ :index, :create, :destroy ], controller: "course_playlists"
    resources :lessons, only: [ :show ] do
      member do
        get :finish
      end
    end
  end
  resources :import_courses, only: [ :new, :create ]
  resources :resync_timestamps, only: [ :new, :create ]
  get "courses/:course_slug/full-player", to: "full_player#show", as: :course_full_player
  resources :playlists, only: [ :show, :destroy ] do
    member do
      get :search_courses, defaults: { format: :json }
    end
  end
  # Learning paths became playlists; keep old URLs (indexed via the sitemap) alive.
  get "/learning_paths/:id", to: redirect("/playlists/%{id}")
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
