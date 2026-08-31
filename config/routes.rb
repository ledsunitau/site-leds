Rails.application.routes.draw do
  devise_for :users, controllers: {
    omniauth_callbacks: "users/omniauth_callbacks",
    sessions: "users/sessions",
    registrations: "users/registrations"
  }

  # Perfil do usuário logado (RF-AUT-06) + desvínculo de contas externas (RF-AUT-05)
  resource :profile, only: %i[show update]
  resources :oauth_identities, only: :destroy

  # Emblemas (RF-EMB): catálogo com raridade + equipar destaque/secundário +
  # o ranking de elo (a escada e o top do elo mais alto).
  resources :emblemas, only: :index do
    collection do
      patch :equipar
      get :ranking
      # cross-check dos cargos da própria pessoa (RF-EMB). Throttled: dispara
      # chamadas externas ao Discord.
      post :sincronizar_discord
    end
  end
  # Link exclusivo. Caminho curto porque é feito para colar em chat; deslogado,
  # o authenticate_user! guarda o stored_location e o Devise devolve para cá
  # depois do login OU do cadastro (cobre e-mail/senha, Google e Discord).
  get "e/:token", to: "emblema_convites#show", as: :emblema_convite

  # Página pública de um usuário (emblemas equipados, projetos, avaliações).
  # Exige login, como a loja (RN-17) — as avaliações citam produto e nota.
  resources :usuarios, only: :show, controller: "perfis_publicos"

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
  resources :ideias, only: %i[index show create new] do
    member do
      post :aprovar
      post :rejeitar
    end
  end

  # Parceiros (RF-PAR): vitrine pública + área do parceiro; o formulário
  # "seja um parceiro" (RF-PAR-03) é público e só cria lead.
  resources :parceiros, only: %i[index show create update]
  resources :parceria_leads, only: :create

  # Loja (RF-LOJ-01): catálogo. Ver exige login — padrão exclusivo da loja
  # (RN-17); cadastrar/editar é de membro para cima (RN-13). `todos` é o catálogo
  # expandido (#LOJA2); avaliações (#LOJA4) são aninhadas ao produto.
  resources :produtos, only: %i[index show create update] do
    collection { get :todos }
    resources :avaliacoes, only: :create
  end

  # Carrinho (RF-LOJ-02) e reservas sob demanda (RF-LOJ-05/06) — do próprio
  # usuário logado. Rotas de item explícitas: "itens" singulariza mal
  # ("iten"), e o resource singular procuraria CarrinhosController.
  get "carrinho", to: "carrinho#show", as: :carrinho
  scope "carrinho", controller: "itens_carrinho", as: "carrinho" do
    post "itens", action: :create, as: :itens
    patch "itens/:id", action: :update, as: :item
    delete "itens/:id", action: :destroy
  end
  resources :reservas, only: %i[index create] do
    member do
      post :cancelar
      post :pagar # RF-LOJ-07: converte a reserva num pedido a pagar
    end
  end

  # Endereços de entrega do usuário (RF-LOJ-04) e cotação de frete (RF-LOJ-11).
  resources :enderecos, only: %i[index create update destroy]
  post "frete/cotar", to: "fretes#cotar"

  # Checkout de estoque (RF-LOJ-04) → pedido + pagamento (Mercado Pago) + frete.
  post "checkout", to: "checkout#create"
  resources :pedidos, only: %i[index show] do
    member do
      post :pagar   # reinicia o pagamento (nova tentativa)
      post :cancelar
    end
  end
  # Webhook do gateway (RF-LOJ-12): público, sem sessão
  post "pagamentos/webhook", to: "pagamentos#webhook"

  # Novidades (RF-NOV): notícias/blog com fila de aprovação (RN-02) +
  # últimas notícias da landing (RF-INI-07) + histórico de versões (RF-NOV-07)
  # new/edit: a tela de escrita fora do painel (RF-NOV-04). Sem ela, escritor e
  # jornalista teriam a autorização da PostPolicy e nenhuma tela para exercê-la —
  # /painel é só diretoria e presidência.
  resources :posts, only: %i[index show new edit create update destroy] do
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

  # Página da comunidade (convite do Discord). Exige login: o "Participe da
  # comunidade" da home traz o visitante pra cá — deslogado passa pelo login e
  # o Devise devolve pra cá (stored_location).
  get "comunidade", to: "comunidade#show"

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
    # RF-LOJ-04: acompanhamento e transições de fulfillment dos pedidos
    resources :pedidos, only: :index do
      member do
        post :em_producao
        post :enviar
        post :entregar
      end
    end
    # Liga/desliga a loja e alterna o modo de pagamento (direto ↔ mercado_pago)
    resource :loja_config, only: :update
  end
  mount MissionControl::Jobs::Engine, at: "/admin/jobs"

  # Painel de gestão (HTML). Separado de /admin de propósito: /admin é a API
  # JSON (contrato testado, rescue_from JSON-only); aqui tudo responde HTML.
  # Mesmo portão de papel — Painel::BaseController.
  get "painel", to: "painel/dashboard#show", as: :painel
  namespace :painel do
    # RF-ADM-04: fila unificada. As transições ficam sob /aprovacoes (e não em
    # /posts ou /ideias) porque quem age aqui é a gestão e o redirect volta
    # para a fila — a rota do autor continua sendo a pública.
    get "aprovacoes", to: "aprovacoes#index", as: :aprovacoes
    scope "aprovacoes", controller: :aprovacoes, as: :aprovacoes do
      post "posts/:id/aprovar",  action: :aprovar_post,  as: :aprovar_post
      post "posts/:id/rejeitar", action: :rejeitar_post, as: :rejeitar_post
      post "ideias/:id/aprovar",  action: :aprovar_ideia,  as: :aprovar_ideia
      post "ideias/:id/rejeitar", action: :rejeitar_ideia, as: :rejeitar_ideia
    end

    resources :denuncias, only: :index do
      member { post :resolver }
    end
    resources :comentarios, only: :index do
      member { post :moderar }
    end
    resources :avaliacoes, only: %i[index destroy]

    # Pessoas: contas/papéis, perfis de membro (com mandatos na própria ficha)
    # e a estrutura (diretorias + gestões) numa tela só.
    resources :usuarios, only: %i[index update]
    # Emblemas: a ficha de edição concentra donos, concessão a dedo e os links
    # exclusivos — mesmo espírito de "variantes dentro do produto".
    resources :emblemas, only: %i[index new create edit update destroy] do
      member do
        post :conceder
        delete :revogar
      end
      resources :convites, only: %i[create update destroy], controller: "emblema_convites"
      # níveis do emblema escalonável: qual rank entra em qual limiar
      resources :niveis, only: %i[create destroy], controller: "emblema_niveis"
    end
    # Catálogo de ranks (bronze…elite) e degraus de elo: as duas escadas que a
    # gestão calibra. Salvar qualquer uma reenfileira o EmblemasJob, porque
    # mexer em peso ou limiar muda a pontuação da base inteira.
    resources :emblema_ranks, only: %i[index create update destroy]
    resources :elos, only: %i[index create update destroy]
    # Espelho dos cargos no servidor do Discord: o GET mostra o diff, o POST
    # aplica. Apagar é sempre opt-in explícito no corpo do POST.
    get "discord", to: "discord#show", as: :discord
    post "discord", to: "discord#sincronizar"
    resources :membros, only: %i[index new create edit update destroy]
    resources :mandatos, only: %i[create update destroy]
    get "estrutura", to: "estrutura#index", as: :estrutura
    resources :diretorias, only: %i[create update destroy]
    resources :gestoes, only: %i[create update destroy]

    # Conteúdo: ações (projeto/evento/artigo), novidades e ideias.
    resources :acoes, only: %i[index new create edit update destroy]
    # Papéis das ações (backend, organizador…): eram enum + CHECK, viraram cadastro.
    resources :funcoes, only: %i[index create update destroy]
    resources :posts, only: %i[index new create edit update destroy] do
      member do
        get :versoes
        post :submeter
      end
    end
    resources :ideias, only: :index do
      member do
        post :aprovar
        post :rejeitar
      end
    end

    # Loja: catálogo (com variantes), categorias, pedidos e reservas.
    resources :produtos, only: %i[index new create edit update]
    resources :categorias, only: %i[index create update destroy]
    resources :pedidos, only: :index do
      member do
        # pagamento presencial (modo "direto"): não há webhook para mover o pedido
        post :marcar_pago
        post :cancelar
        post :em_producao
        post :enviar
        post :entregar
      end
    end
    resources :reservas, only: :index
    post "reservas/disparar/:id", to: "reservas#disparar", as: :disparar_reserva

    # Parceiros, leads e os catálogos reutilizáveis.
    resources :parceiros, only: %i[index new create edit update destroy]
    resources :leads, only: %i[index destroy] do
      member do
        post :converter
        post :recusar
      end
    end
    # Tecnologias, temas e congressos têm a mesma forma; o :tipo escolhe qual,
    # sempre dentro de um mapa fechado no controller (nunca constantize).
    get "catalogos", to: "catalogos#index", as: :catalogos
    post "catalogos/:tipo", to: "catalogos#create", as: :criar_catalogo
    patch "catalogos/:tipo/:id", to: "catalogos#update", as: :catalogo_item
    delete "catalogos/:tipo/:id", to: "catalogos#destroy"

    # Sistema: recursos (flags), limiares de alerta, logs, auditoria e LGPD.
    get "recursos", to: "recursos#index", as: :recursos
    patch "recursos", to: "recursos#update"
    patch "recursos/modo_pagamento", to: "recursos#modo_pagamento", as: :recursos_modo_pagamento
    patch "recursos/limiares", to: "recursos#limiares", as: :recursos_limiares

    get "metricas", to: "metricas#show", as: :metricas
    resources :logs, only: %i[index show]
    get "auditoria", to: "auditoria#index", as: :auditoria
    get "lgpd", to: "lgpd#index", as: :lgpd
    delete "lgpd", to: "lgpd#eliminar"
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "home#index"
end
