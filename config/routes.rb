Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # API routes
  namespace :api do
    namespace :v1 do
      # Authentication routes
      devise_for :users,
                 controllers: {
                   sessions: "api/v1/sessions",
                   registrations: "api/v1/registrations"
                 },
                 skip: [:passwords, :confirmations, :unlocks],
                 path: "",
                 path_names: {
                   sign_in: "users/sign_in",
                   sign_out: "users/sign_out",
                   registration: "users"
                 }

      # Blueprint routes with nested milestones and habits
      resources :blueprints do
        member do
          patch :complete
        end
        resources :milestones do
          member do
            patch :complete
          end
          resources :habits do
            member do
              patch :mark_completed
              patch :reset
            end
          end
        end
      end

      # Standalone milestones routes for direct access
      resources :milestones, only: [:show, :update, :destroy] do
        resources :habits do
          member do
            patch :mark_completed
            patch :reset
          end
        end
      end

      # Standalone habits routes for direct access
      resources :habits, except: [:index] do
        member do
          post :mark_completed
          post :reset
        end
      end
      resources :habits, only: [:show, :update, :destroy] do
        member do
          post :mark_completed
          post :reset
        end
      end

      # Achievement/Badge system routes
      resources :achievements, only: [ :index ] do
        collection do
          get :user, to: "achievements#user_achievements"
          get :stats
          get :leaderboard
          get :progress
          get :recent
          get :debug
          post :award
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

      # Google Calendar integration routes
      get "calendar/events", to: "calendar#events"
      get "calendar/sync_status", to: "calendar#sync_status"
      post "calendar/bulk_sync", to: "calendar#bulk_sync"
      
      # Habit calendar events
      post "calendar/habits/:habit_id/event", to: "calendar#create_habit_event"
      post "calendar/habits/:habit_id/recurring_events", to: "calendar#create_recurring_habit_events"
      
      # Milestone calendar events
      post "calendar/milestones/:milestone_id/event", to: "calendar#create_milestone_event"
      
      # Event management
      put "calendar/events/:event_id", to: "calendar#update_event"
      delete "calendar/events/:event_id", to: "calendar#delete_event"
    end
  end

  # Health check endpoint
  get "health", to: "application#health"

  # Defines the root path route ("/")
  # root "posts#index"
end
