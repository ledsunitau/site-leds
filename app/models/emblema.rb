# Emblema (RF-EMB): conquista customizável pela gestão — ícone SVG, cor, efeito
# animado e forma de aquisição. A raridade NÃO é escolhida: sai do % de usuários
# que o possuem sobre o total de contas.
#
# Auditado (PaperTrail): criar/editar emblema é ato de gestão, como Setting.
#
# DOIS TIPOS:
#   unico       — você tem ou não tem. Ganho por meta, concessão, link ou compra.
#   escalonavel — sobe de rank (bronze → elite) conforme cumpre de novo. Os
#                 degraus vivem em emblema_niveis (rank + limiar).
#
# A FONTE DO PROGRESSO do escalonável é derivada, sem coluna: COM `criterio`
# conta a métrica; SEM, conta os registros (EmblemaConquista). Uma coluna a
# mais aqui seria um segundo lugar para a mesma verdade.
#
# Quatro formas de ganhar, e a `origem` da EmblemaConquista registra qual foi:
#   meta      — bateu o critério (EmblemasJob / Emblema.avaliar!)
#   concessao — a gestão deu a dedo no painel
#   convite   — resgatou um link exclusivo (EmblemaConvite)
#   compra    — pagamento confirmado de um pedido com o produto vinculado
class Emblema < ApplicationRecord
  has_paper_trail

  has_many :emblema_usuarios, dependent: :destroy
  has_many :usuarios, through: :emblema_usuarios, source: :user
  has_many :convites, class_name: "EmblemaConvite", dependent: :destroy, inverse_of: :emblema
  has_many :niveis, class_name: "EmblemaNivel", dependent: :destroy, inverse_of: :emblema
  # produto que concede o emblema na confirmação do pagamento (RF-EMB/RF-LOJ)
  belongs_to :produto, optional: true, inverse_of: false

  TIPOS = %w[unico escalonavel].freeze

  # ---------------------------------------------------------------- Registros

  # Critérios de conquista. REGISTRO FECHADO, no espírito de Setting::FLAGS e
  # NotificationPreference::CATEGORIAS: o gestor escolhe a chave num select e
  # digita a meta. Texto livre aqui viraria critério fantasma que nada avalia.
  #
  # Todo `conta` é montado sobre escopo que já existe — critério novo é uma
  # linha aqui + a chave no CHECK da migração.
  CRITERIOS = {
    "novidades_publicadas" => {
      label: "Novidades publicadas",
      conta: ->(user) { Post.publicados.where(autor: user).count }
    },
    "ideias_aprovadas" => {
      label: "Ideias aprovadas",
      conta: ->(user) { user.ideias.aprovada.count }
    },
    "acoes_participadas" => {
      label: "Ações participadas",
      conta: ->(user) { user.acoes_creditadas.count }
    },
    "comentarios" => {
      label: "Comentários publicados",
      conta: ->(user) { user.comentarios.visiveis.count }
    },
    "avaliacoes" => {
      label: "Avaliações de produto",
      conta: ->(user) { user.avaliacoes.count }
    },
    "pedidos_pagos" => {
      label: "Pedidos pagos",
      conta: ->(user) { user.pedidos.where(status: Pedido::PAGOS).count }
    },
    "dias_de_conta" => {
      label: "Dias de conta",
      conta: ->(user) { (Date.current - user.created_at.to_date).to_i }
    }
  }.freeze

  EFEITOS = %w[nenhum brilho neon arco_iris pulso].freeze
  EFEITO_LABEL = {
    "nenhum" => "Nenhum", "brilho" => "Brilho (ouro/prata)", "neon" => "Neon",
    "arco_iris" => "Arco-íris", "pulso" => "Pulso"
  }.freeze

  # ------------------------------------------------------------- Cosmético
  #
  # A pintura que a pessoa VESTE (nome + anel do avatar) ao desbloquear este
  # emblema. Separada de cor/efeito, que pintam o ÍCONE: o ícone é a identidade
  # do emblema no catálogo, o cosmético é o que a pessoa leva para o perfil.
  #
  # A exclusividade mora no GRADIENTE, com índice único no banco — o movimento
  # vem de uma lista fechada porque é só o motor da animação. Duas ou três cores
  # próprias já dão combinação infinita, então nenhuma pintura se repete sem que
  # a lista de efeitos precise crescer.
  MOVIMENTOS = %w[parado varredura fluxo pulso].freeze
  MOVIMENTO_LABEL = {
    "parado" => "Parado", "varredura" => "Varredura (brilho passando)",
    "fluxo" => "Fluxo (cores correndo)", "pulso" => "Pulso"
  }.freeze
  GRADIENTE_FORMATO = /\A#\h{6}(,#\h{6}){1,2}\z/

  # Faixas de raridade por % de donos, do mais comum ao mais raro. O primeiro
  # piso que o percentual alcança ganha; a última entra como piso zero.
  FAIXAS = [
    [ 50.0, "comum",    "Comum" ],
    [ 25.0, "incomum",  "Incomum" ],
    [ 10.0, "raro",     "Raro" ],
    [ 2.0,  "epico",    "Épico" ],
    [ 0.0,  "lendario", "Lendário" ]
  ].freeze

  # ------------------------------------------------------------ Ícone (SVG)

  # Safelist do sanitizer. O que NÃO está aqui é removido — inclusive script,
  # style, foreignObject, use/href e todo handler on*. `sanitize` vem do
  # rails-html-sanitizer, dependência do Action View (nenhuma gem nova).
  TAGS_SVG = %w[svg g path circle ellipse rect line polyline polygon
                defs linearGradient radialGradient stop title desc].freeze
  ATRIBUTOS_SVG = %w[viewBox xmlns width height class id
                     d points transform opacity
                     fill fill-rule fill-opacity clip-rule
                     stroke stroke-width stroke-linecap stroke-linejoin
                     stroke-dasharray stroke-opacity
                     cx cy r rx ry x y x1 y1 x2 y2
                     offset stop-color stop-opacity gradientUnits gradientTransform].freeze
  TAMANHO_MAX_SVG = 20.kilobytes

  # -------------------------------------------------------------- Validação

  validates :nome, presence: true, uniqueness: true
  validates :icone_svg, presence: true, length: { maximum: TAMANHO_MAX_SVG }
  validates :cor, format: { with: /\A#\h{6}\z/, message: "deve ser um hexadecimal como #00C55B" }
  validates :efeito, inclusion: { in: EFEITOS }
  validates :criterio, inclusion: { in: CRITERIOS.keys }, allow_nil: true
  validates :meta, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :tipo, inclusion: { in: TIPOS }
  validates :peso, numericality: { only_integer: true, greater_than: 0 }
  validates :limite_donos, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :meta_acompanha_criterio

  validates :cosmetico_gradiente,
            format: { with: GRADIENTE_FORMATO,
                      message: "deve ser 2 ou 3 cores hexadecimais separadas por vírgula" },
            uniqueness: { message: "já é o cosmético de outro emblema — cada pintura é exclusiva" },
            allow_blank: true
  validates :cosmetico_movimento, inclusion: { in: MOVIMENTOS }
  validates :cosmetico_velocidade, numericality: { only_integer: true, in: 1..30 }

  before_validation :sanitizar_icone
  before_validation :normalizar_gradiente

  scope :ativos, -> { where(ativo: true) }
  scope :com_meta, -> { where.not(criterio: nil) }
  scope :ordenados, -> { order(:usuarios_count, :nome) } # do mais raro para o mais comum

  def escalonavel? = tipo == "escalonavel"
  def unico? = tipo == "unico"

  # ------------------------------------------------------------- Cosmético

  def cosmetico? = cosmetico_gradiente.present?

  def cosmetico_cores = cosmetico_gradiente.to_s.split(",")

  # O gradiente pronto para o CSS. A primeira cor é repetida no fim para o
  # movimento de fluxo emendar sem costura quando a posição dá a volta — mas só
  # quando ela ainda NÃO fecha o ciclo: num "#FFEE04,#FF8A00,#FFEE04" a repetição
  # criaria um trecho chapado de duas paradas iguais no meio da animação.
  def cosmetico_css
    return nil if cosmetico_cores.empty?

    "linear-gradient(100deg, #{cosmetico_cores_fechadas})"
  end

  # A lista de cores com a primeira repetida no fim, quando ela ainda não fecha
  # o ciclo. É o que faz o ladrilho emendar sem costura no linear e o anel do
  # header (conic-gradient) fechar a volta sem um corte visível.
  def cosmetico_cores_fechadas
    cores = cosmetico_cores
    return nil if cores.empty?

    cores += [ cores.first ] unless cores.last == cores.first
    cores.join(", ")
  end

  scope :com_cosmetico, -> { where.not(cosmetico_gradiente: nil) }

  # Escalonável sem critério sobe por registro (maratona); com critério, pela
  # métrica (ideias aprovadas). Único nunca "sobe" — é binário.
  def por_registro? = escalonavel? && criterio.blank?

  # --------------------------------------------------------------- Raridade

  # Total de contas: uma consulta por janela de 5 min para o catálogo inteiro,
  # no mesmo padrão de cache do PainelMetricas. Sem isto seria um COUNT por
  # emblema renderizado.
  def self.total_usuarios
    Rails.cache.fetch("emblemas/total_usuarios", expires_in: 5.minutes) { User.count }
  end

  # Arredondado ANTES de escolher a faixa, de propósito: assim o número que a
  # tela mostra e a faixa que ela escreve nunca se contradizem ("2,0% · Épico"
  # não acontece).
  def percentual
    total = self.class.total_usuarios
    return 0.0 if total.zero?

    (usuarios_count * 100.0 / total).round(1)
  end

  def raridade = FAIXAS.find { |piso, _, _| percentual > piso }&.second || "lendario"

  def raridade_label = FAIXAS.find { |_, chave, _| chave == raridade }&.third

  # -------------------------------------------------------------- Aquisição

  def criterio_config = CRITERIOS[criterio]

  # "Novidades publicadas: 5". Rótulo antes do número de propósito: uma frase
  # com verbo ("Publique 1 ideias aprovadas") exigiria singular e plural de
  # cada critério para não sair torta — e a barra de progresso logo abaixo já
  # dá o "quanto falta".
  def como_conseguir
    return "Sobe a cada registro da gestão." if por_registro?
    return "Concedido pela gestão." if criterio.blank?
    return criterio_config[:label] if escalonavel?

    "#{criterio_config[:label]}: #{meta}"
  end

  # Quanto o usuário tem HOJE. Escalonável por registro conta as conquistas
  # gravadas; o resto conta a métrica. Único usa isso só para a barra do catálogo.
  def progresso_de(user)
    return 0 if user.nil?
    return emblema_usuarios.where(user: user).pick(:conquistas_count).to_i if por_registro?

    criterio.present? ? criterio_config[:conta].call(user) : 0
  end

  def atingido_por?(user) = criterio.present? && unico? && progresso_de(user) >= meta.to_i

  # O degrau alcançado com esse progresso. nil = ainda abaixo do primeiro limiar.
  def nivel_para(progresso) = niveis.do_maior.find_by("limiar <= ?", progresso.to_i)

  # Teto de donos ("os 10 primeiros que comprarem"). Já contando quem tem.
  def lotado? = limite_donos.present? && usuarios_count >= limite_donos

  # Registra um cumprimento. Emblema ÚNICO só aceita o primeiro (devolve nil
  # depois disso); ESCALONÁVEL acumula, e cada chamada pode subir o rank.
  #
  # with_lock quando há teto de donos: sem ele, dois pagamentos confirmados no
  # mesmo instante leem "9 donos" e ambos entram, furando o "os 10 primeiros".
  # Só trava quando o teto existe — concessão comum não paga o preço do lock.
  def conceder!(user, origem:, descricao: nil, por: nil, convite: nil, pedido: nil, ocorrido_em: nil)
    if limite_donos.present?
      with_lock { registrar(user, origem, descricao, por, convite, pedido, ocorrido_em) }
    else
      registrar(user, origem, descricao, por, convite, pedido, ocorrido_em)
    end
  end

  # Tira o emblema INTEIRO (todos os registros). O cargo do Discord vai junto:
  # o cargo é consequência do emblema, deixá-lo seria um privilégio órfão.
  def revogar!(user)
    vinculo = emblema_usuarios.find_by(user: user)
    return if vinculo.nil?

    cargos = [ discord_role_id, vinculo.nivel&.discord_role_id ].compact
    vinculo.destroy!
    cargos.each { |cargo| DiscordCargoJob.perform_later(user.id, cargo, "remover") }
    user.recalcular_elo!
  end

  # Reavaliação disparada por PAGEVIEW (perfil e catálogo de emblemas), no
  # máximo uma vez por JANELA por usuário.
  #
  # POR QUE existe separado de avaliar!: aquele é a varredura autoritativa (o
  # EmblemasJob da hora cheia) e não pode ser pulado. Este é o atalho de
  # conveniência das telas — abrir o perfil três vezes seguidas repetia um COUNT
  # por emblema com meta, mais as escritas de conceder!, dentro de um GET.
  #
  # A janela não atrasa quem acabou de bater a meta: a primeira visita depois do
  # feito cai fora da janela e avalia. O que ela corta é a repetição.
  #
  # Mesmo padrão de cache de total_usuarios. Em teste o store é :null_store, então
  # o write é no-op e isto se comporta exatamente como avaliar! — de propósito:
  # nenhum teste existente muda de resultado por causa da janela.
  JANELA_AVALIACAO = 5.minutes

  def self.avaliar_recente!(user)
    chave = "emblemas/avaliado/#{user.id}"
    return if Rails.cache.read(chave)

    Rails.cache.write(chave, true, expires_in: JANELA_AVALIACAO)
    avaliar!(user)
  end

  # Concede ao usuário todo emblema ÚNICO com meta que ele já bateu, e reavalia
  # o rank dos escalonáveis de métrica. Chamado pelo EmblemasJob (varredura
  # horária) e, via avaliar_recente!, quando o próprio usuário abre suas telas.
  def self.avaliar!(user)
    return unless Setting.ativo?("emblemas_ativos")

    ja_tem = EmblemaUsuario.where(user: user).pluck(:emblema_id)
    ativos.com_meta.find_each do |emblema|
      if emblema.escalonavel?
        emblema.acompanhar_metrica!(user)
      elsif !ja_tem.include?(emblema.id) && emblema.atingido_por?(user)
        emblema.conceder!(user, origem: "meta")
      end
    end
  end

  # Escalonável de MÉTRICA: o vínculo nasce quando a pessoa cruza o primeiro
  # limiar e o rank acompanha a métrica daí em diante. Sem conquista por degrau —
  # o "registro" desses emblemas é a própria métrica, não um evento datado.
  def acompanhar_metrica!(user)
    progresso = progresso_de(user)
    nivel = nivel_para(progresso)
    return if nivel.nil? # ainda não chegou no bronze

    vinculo = emblema_usuarios.find_by(user: user)
    if vinculo.nil?
      return if lotado?

      vinculo = EmblemaUsuario.create!(emblema: self, user: user)
      vinculo.conquistas.create!(origem: "meta", descricao: criterio_config[:label])
      EmblemaConcedidoNotifier.with(record: self).deliver(user)
      DiscordCargoJob.perform_later(user.id, discord_role_id, "adicionar") if discord_role_id.present?
    end
    vinculo.aplicar_nivel!(nivel)
  rescue ActiveRecord::RecordNotUnique
    nil # corrida com outro job: o vínculo já existe, o próximo passe ajusta
  end

  private

  def registrar(user, origem, descricao, por, convite, pedido, ocorrido_em)
    vinculo = emblema_usuarios.find_by(user: user)
    return nil if vinculo && unico? # já tem: nada a acrescentar
    return nil if vinculo.nil? && lotado?

    novo = vinculo.nil?
    vinculo ||= EmblemaUsuario.create!(emblema: self, user: user)
    vinculo.conquistas.create!(origem: origem, descricao: descricao, concedido_por: por,
                               convite: convite, pedido: pedido, ocorrido_em: ocorrido_em)

    if novo
      EmblemaConcedidoNotifier.with(record: self).deliver(user)
      DiscordCargoJob.perform_later(user.id, discord_role_id, "adicionar") if discord_role_id.present?
    end
    vinculo.aplicar_nivel!(nivel_para(vinculo.reload.conquistas_count)) if por_registro?
    user.recalcular_elo!
    vinculo
  rescue ActiveRecord::RecordNotUnique
    nil # corrida no índice único de (user, emblema): o outro lado ganhou
  end

  # Sem normalizar, "#ff0000,#00ff00" e "#FF0000, #00FF00" passariam pelo índice
  # único como pinturas diferentes — e sairiam idênticas na tela.
  #
  # Vazio vira NULL, não "": o índice único é PARCIAL (WHERE ... IS NOT NULL),
  # então "" contaria como pintura e o SEGUNDO emblema sem cor colidiria com o
  # primeiro. Um campo de texto em branco no formulário chega como "".
  def normalizar_gradiente
    if cosmetico_gradiente.blank?
      self.cosmetico_gradiente = nil
    else
      self.cosmetico_gradiente = cosmetico_gradiente.gsub(/\s+/, "").upcase
    end
  end

  def sanitizar_icone
    return if icone_svg.blank?

    self.icone_svg = ActionController::Base.helpers.sanitize(
      icone_svg, tags: TAGS_SVG, attributes: ATRIBUTOS_SVG
    ).to_s.strip
  end

  # Escalonável não usa `meta`: os limiares vivem em emblema_niveis, um por rank.
  def meta_acompanha_criterio
    if escalonavel?
      errors.add(:meta, "não se usa em emblema escalonável — o limiar fica em cada rank") if meta.present?
    elsif criterio.present? && meta.blank?
      errors.add(:meta, "é obrigatória quando há critério")
    elsif criterio.blank? && meta.present?
      errors.add(:meta, "só faz sentido com um critério")
    end
  end
end
