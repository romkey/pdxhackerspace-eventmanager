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
  devise_for :users, controllers: {
    omniauth_callbacks: 'omniauth_callbacks'
  }

  # Root path
  root 'home#index'

  # Events routes
  resources :events do
    member do
      post :postpone
      post :cancel
      post :reactivate
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
end
