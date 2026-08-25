# Configurações controladas pela gestão (painel → Recursos). Key/value com um
# REGISTRO fechado: chave desconhecida levanta, em vez de virar flag fantasma
# que ninguém sabe se está ligada.
#
# Auditado (PaperTrail) porque ligar/desligar um recurso é ato de gestão.
#
# Leitura: uma consulta por processo, cacheada e invalidada na escrita. Antes
# era um find_by por chamada — a barra da loja sozinha custava 3 por request, e
# com o painel de flags isso viraria uma consulta por ponto de leitura.
class Setting < ApplicationRecord
  has_paper_trail

  validates :chave, presence: true, uniqueness: true

  CACHE = "settings/mapa".freeze

  MODOS_PAGAMENTO = %w[direto mercado_pago].freeze

  # Recursos liga/desliga. `default` é o que vale sem linha no banco — todo
  # recurso nasce LIGADO menos manutenção, senão um deploy limpo derrubaria
  # metade do site.
  FLAGS = {
    "loja_ativa" => {
      label: "Loja", default: true,
      descricao: "Catálogo, carrinho e checkout. Desligada, o visitante vê “indisponível”; quem cadastra continua enxergando."
    },
    "ideias_ativas" => {
      label: "Ideias", default: true,
      descricao: "Envio de ideias pela comunidade. Desligado, o formulário some e a rota recusa."
    },
    "comentarios_ativos" => {
      label: "Comentários", default: true,
      descricao: "Comentar novidades. Desligado, os comentários existentes continuam visíveis; só não entram novos."
    },
    "avaliacoes_ativas" => {
      label: "Avaliações de produto", default: true,
      descricao: "Avaliar produto comprado. Desligado, as notas existentes continuam aparecendo."
    },
    "parceria_ativa" => {
      label: "Formulário de parceria", default: true,
      descricao: "Recebimento de novos leads na página de Parceiros."
    },
    "emblemas_ativos" => {
      label: "Emblemas", default: true,
      descricao: "Conquista de emblemas por meta e resgate de link exclusivo. Desligado, ninguém ganha emblema novo; os já conquistados continuam equipados e visíveis."
    },
    "cadastro_publico" => {
      label: "Cadastro de novas contas", default: true,
      descricao: "Criar conta por e-mail e por Google/Discord. Desligado, só quem já tem conta entra."
    },
    "manutencao" => {
      label: "Modo manutenção", default: false,
      descricao: "Fecha o site para quem não é da gestão. O painel, o login e o webhook de pagamento continuam de pé."
    }
  }.freeze

  # Limiares dos alertas (AlertasJob). Números, não booleanos — por isso fora de
  # FLAGS. Editáveis na tela para não precisar de deploy só para calibrar.
  LIMIARES = {
    "alerta_aprovacoes_dias" => { label: "Fila de aprovação parada há (dias)", default: 3 },
    "alerta_denuncias" => { label: "Denúncias pendentes acima de", default: 5 },
    "alerta_erros_hora" => { label: "Erros graves na última hora acima de", default: 10 },
    "alerta_pedidos_horas" => { label: "Pedido pago sem avançar há (horas)", default: 48 }
  }.freeze

  after_commit :expirar_cache

  class << self
    # ---- Recursos (booleanos) ----

    def ativo?(chave)
      config = FLAGS.fetch(chave.to_s) # chave fora do registro é erro de código
      valor = mapa[chave.to_s]
      valor.nil? ? config[:default] : valor == "true"
    end

    def ativar!(chave, ligado)
      FLAGS.fetch(chave.to_s)
      gravar(chave.to_s, ligado ? "true" : "false")
    end

    # ---- Limiares (números) ----

    def limiar(chave)
      config = LIMIARES.fetch(chave.to_s)
      (mapa[chave.to_s].presence || config[:default]).to_i
    end

    def limiar!(chave, valor)
      LIMIARES.fetch(chave.to_s)
      gravar(chave.to_s, valor.to_i.to_s)
    end

    # ---- Loja (mantidos: já consumidos por carrinho, checkout e produtos) ----

    def loja_ativa? = ativo?("loja_ativa")

    # setter não aceita definição endless (erro de sintaxe em Ruby)
    def loja_ativa=(valor)
      ativar!("loja_ativa", valor)
    end

    # direto = intenção de compra (gestão fecha por contato); mercado_pago = gateway.
    def modo_pagamento
      valor = mapa["modo_pagamento"]
      MODOS_PAGAMENTO.include?(valor) ? valor : "direto"
    end

    def modo_pagamento=(valor)
      gravar("modo_pagamento", valor.to_s)
    end

    private

    # Uma consulta, cacheada até alguém escrever. Sem TTL de propósito: a
    # invalidação é exata (after_commit), então um TTL só serviria para atrasar
    # o efeito de desligar a loja.
    def mapa
      Rails.cache.fetch(CACHE) { pluck(:chave, :valor).to_h }
    end

    def gravar(chave, valor)
      find_or_initialize_by(chave: chave).update!(valor: valor)
    end
  end

  private

  def expirar_cache
    Rails.cache.delete(CACHE)
  end
end
