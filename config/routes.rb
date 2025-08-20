Rails.application.routes.draw do
  # Standard Devise routes
  devise_for :users

  # API routes with JWT authentication
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      devise_for :users,
                 controllers: {
                   sessions: 'api/v1/sessions',
                   registrations: 'api/v1/registrations'
                 },
                 as: :api_v1,
                 path: '',
                 path_names: {
                   sign_in: 'login',
                   sign_out: 'logout',
                   registration: 'signup'
                 }
    end
  end
  
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html        

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500. 
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end