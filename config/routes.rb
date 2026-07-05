Rails.application.routes.draw do
  devise_for :users, controllers: {
    omniauth_callbacks: "users/omniauth_callbacks",
    sessions: "users/sessions"
  }

  # Perfil do usuário logado (RF-AUT-06) + desvínculo de contas externas (RF-AUT-05)
  resource :profile, only: %i[show update]
  resources :oauth_identities, only: :destroy

  # Membros: cards com filtros (RF-MEM), grafo (RF-GRA) e geneograma (RF-GEN)
  resources :members, only: %i[index show] do
    collection do
      get :grafo
      get :geneograma
    end
  end

  # Ações (RF-ACO): projetos/eventos/artigos + destaque da landing (RF-INI-02)
  # + calendário de eventos e .ics (RF-ACO-09)
  resources :acoes, only: %i[index show create update] do
    collection do
      get :destaque
      get :calendario
    end
    member do
      get :ics
    end
  end
  resources :tecnologias, only: %i[index create]
  resources :congressos, only: %i[index create]
  resources :temas, only: :index

  # Novidades (RF-NOV): notícias/blog com fila de aprovação (RN-02) +
  # últimas notícias da landing (RF-INI-07) + histórico de versões (RF-NOV-07)
  resources :posts, only: %i[index show create update destroy] do
    collection do
      get :ultimas
      get :meus
    end
    member do
      post :submeter
      post :aprovar
      post :rejeitar
      get :versoes
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "home#index"
end
