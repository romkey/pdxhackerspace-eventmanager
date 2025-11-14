require 'sidekiq/web'
require 'sidekiq-scheduler/web'

Rails.application.routes.draw do
  get 'calendar/index'
  get 'event_occurrences/show'
  get 'event_occurrences/edit'
  get 'event_occurrences/update'
  get 'event_occurrences/destroy'
  get 'event_occurrences/postpone'
  get 'event_occurrences/cancel'
  get 'event_occurrences/reactivate'
  # Devise routes with OmniAuth
  # Users created via Authentik OAuth only (no signup)
  # Keep edit/update for profile management, skip new/create
  devise_for :users, controllers: {
    omniauth_callbacks: 'omniauth_callbacks'
  }, skip_helpers: [:registrations]

  # Manually add only edit/update registration routes (no new/create)
  devise_scope :user do
    resource :registration, only: %i[edit update], controller: 'devise/registrations', as: :user_registration
  end

  # Sidekiq Web UI (admin only)
  authenticate :user, ->(user) { user.admin? } do
    mount Sidekiq::Web => '/sidekiq'
  end

  # Root path
  root 'home#index'

  # Health check endpoints (for monitoring and load balancers)
  get '/health', to: 'health#health'
  get '/health/liveness', to: 'health#liveness'
  get '/health/readiness', to: 'health#readiness'

  # Events routes
  resources :events do
    member do
      post :postpone
      post :cancel
      post :reactivate
      get :embed
    end

    # Host management
    resources :event_hosts, only: %i[create destroy], shallow: true
  end

  # Event Occurrences routes
  resources :event_occurrences, only: %i[show edit update destroy], path: 'occurrences' do
    member do
      post :postpone
      post :cancel
      post :reactivate
    end
  end

  # Calendar view
  get 'calendar', to: 'calendar#index', as: 'calendar'
  get 'calendar/embed', to: 'calendar#embed', as: 'calendar_embed'

  # Site-wide public iCal feed
  get 'calendar.ics', to: 'calendar#ical', as: 'calendar_ical'

  # Public iCal feed
  get 'events/:token/ical', to: 'events#ical', as: 'event_ical'

  # Users management (admin only)
  resources :users, only: %i[index show edit update destroy] do
    member do
      post :make_admin
    end
  end

  # Site configuration (admin only, singleton)
  resource :site_config, only: %i[edit update]

  # Location information page (public)
  get 'location', to: 'site_configs#location', as: 'location_info'

  # Locations management (admin only)
  resources :locations, except: %i[show]
end
