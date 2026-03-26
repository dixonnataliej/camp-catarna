Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "dashboard#index"
  get "history", to: "history#index"

  get  "week_advance/new",     to: "week_advances#new",     as: :new_week_advance
  post "week_advance/weather", to: "week_advances#weather", as: :weather_week_advance
  post "week_advance/health",  to: "week_advances#health",  as: :health_week_advance
  post "week_advance/food",    to: "week_advances#food",    as: :food_week_advance
  post "week_advance/workers", to: "week_advances#workers", as: :workers_week_advance
  post "week_advance/results", to: "week_advances#results", as: :results_week_advance
  post "week_advance/confirm", to: "week_advances#confirm", as: :confirm_week_advance
end
