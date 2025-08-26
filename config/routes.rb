Rails.application.routes.draw do
  # Standard Devise routes
  devise_for :users

  # API routes with JWT authentication
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      devise_for :users,
                 controllers: {
                   sessions: "api/v1/sessions",
                   registrations: "api/v1/registrations"
                 },
                 as: :api_v1,
                 path: "",
                 path_names: {
                   sign_in: "login",
                   sign_out: "logout",
                   registration: "signup"
                 }
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # API routes
  namespace :api do
    namespace :v1 do
      # Blueprint routes with nested milestones and habits
      resources :blueprints do
        resources :milestones do
          resources :habits do
            member do
              post :mark_completed
              post :reset
            end
          end
        end
      end

      # Quotes routes
      resources :quotes, only: [ :index, :create, :destroy ] do
        collection do
          get :random
          get :celebration
          get "tags/:tags", to: "quotes#by_tags"
          get "blueprint/:blueprint_id", to: "quotes#blueprint_quote"
        end
      end

      # Spotify integration routes
      namespace :spotify do
        get "tracks/blueprint/:blueprint_id", to: "spotify#blueprint_tracks"
        get "playlists/:category", to: "spotify#category_playlists"
        post "playlist/blueprint/:blueprint_id", to: "spotify#create_blueprint_playlist"
        get "recommendations/blueprint/:blueprint_id", to: "spotify#blueprint_recommendations"
        get "audio_features", to: "spotify#audio_features"
        get "search", to: "spotify#search"
        get "habit_music/:habit_id", to: "spotify#habit_music"
        get "daily_motivation", to: "spotify#daily_motivation"
      end

      # Achievement/Badge system routes
      resources :achievements, only: [ :index ] do
        collection do
          get :user, to: "achievements#user_achievements"
          get :stats
          get :leaderboard
          get :progress
          get :recent
          post :seed
          post "check/:type", to: "achievements#check_achievements"
        end

        member do
          get "categories/:category", to: "achievements#by_category"
        end
      end

      # Email notification routes
      namespace :notifications do
        post :habit_completion
        post :milestone_progress
        post :blueprint_completion
        post :daily_summary
        post :achievement_notification
        post :habit_reminder
        post :test_email
        get :preferences
        put :preferences, to: "notifications#update_preferences"
        get :history
      end

      # Future authentication routes (for when we add Devise)
      # post 'auth/sign_up', to: 'auth#sign_up'
      # post 'auth/sign_in', to: 'auth#sign_in'
      # delete 'auth/sign_out', to: 'auth#sign_out'
    end
  end

  # Health check endpoint
  get "health", to: "application#health"

  # Defines the root path route ("/")
  # root "posts#index"
end

