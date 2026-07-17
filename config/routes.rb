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

  # Ideias (RF-IDE): comunidade propõe (RN-01), gestão revisa (RF-IDE-04)
  resources :ideias, only: %i[index show create] do
    member do
      post :aprovar
      post :rejeitar
    end
  end

  # Parceiros (RF-PAR): vitrine pública + área do parceiro; o formulário
  # "seja um parceiro" (RF-PAR-03) é público e só cria lead.
  resources :parceiros, only: %i[index show create update]
  resources :parceria_leads, only: :create

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
    # RF-NOV-08: comentários de um post
    resources :comentarios, only: %i[index create]
  end

  # Moderar comentário (RF-NOV-10) e denunciar (RF-NOV-09) independem do post
  resources :comentarios, only: [] do
    member { post :moderar }
    resources :denuncias, only: :create
  end

  # Métricas da landing (RF-INI-01)
  get "metricas", to: "metricas#show"

  # Notificações (RF-NOT): centro in-app, preferências por canal/categoria e
  # inscrições de Web Push (VAPID).
  resources :notifications, only: :index do
    member { post :read }
    collection { post :read_all }
  end
  resources :notification_preferences, only: %i[index create]
  resources :push_subscriptions, only: %i[create destroy] do
    collection { get :vapid_public_key }
  end

  # LGPD e analytics (Cluster 8): consentimento de cookies (RNF-04/05) +
  # coleta de eventos só com consentimento (RN-14). Ambos públicos.
  resources :consents, only: :create
  resources :events, only: :create

  # Admin (RF-ADM): tudo atrás do gate de gestão do Admin::BaseController
  namespace :admin do
    resources :error_logs, only: %i[index show]
    resources :users, only: %i[index update]
    resources :members, only: %i[create update destroy]
    resources :mandatos, only: %i[create update destroy]
    resources :diretorias, only: %i[create update]
    resources :gestoes, only: :create
    resources :approvals, only: :index
    resources :audits, only: :index
    resource :metrics, only: :show
    # RF-PAR-04: triagem dos leads de parceria (destroy = eliminação LGPD)
    resources :parceria_leads, only: %i[index destroy] do
      member do
        post :converter
        post :recusar
      end
    end
    # RF-ADM-05: aba de denúncias
    resources :denuncias, only: :index do
      member { post :resolver }
    end
  end
  mount MissionControl::Jobs::Engine, at: "/admin/jobs"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "home#index"
end
