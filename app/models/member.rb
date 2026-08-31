class Member < ApplicationRecord
  include ImagemValidavel
  valida_imagem :foto

  belongs_to :user
  # RF-GEN-04: quem trouxe o membro para a liga (registrado, mas não é o eixo
  # visual do geneograma — RN-07).
  belongs_to :padrinho, class_name: "Member", optional: true
  has_many :afilhados, class_name: "Member", foreign_key: :padrinho_id,
                       dependent: :nullify, inverse_of: :padrinho
  has_many :mandatos, dependent: :destroy
  # Skills do card (RF-MEM): tecnologias que o membro domina.
  has_many :member_tecnologias, dependent: :destroy
  has_many :tecnologias, through: :member_tecnologias

  # Foto institucional do card (RF-MEM-06); sem ela, o card usa a foto de
  # perfil do usuário (fallback em foto_para_card).
  # Espelha User#foto — o porquê dos dois tamanhos está lá. Tem que ser igual:
  # foto_para_card devolve esta OU a do user, e o chamador pede a variante sem
  # saber de qual das duas ela veio.
  has_one_attached :foto do |anexo|
    anexo.variant :avatar,  resize_to_fill:  [ 192, 192 ], **ImagemValidavel::VARIANTE
    anexo.variant :retrato, resize_to_limit: [ 720, 900 ], **ImagemValidavel::VARIANTE
  end

  validates :user_id, uniqueness: true
  validate :padrinho_nao_pode_ser_si_mesmo
  # Os três links viram href no card (members/index): só http(s) entra, senão um
  # "javascript:…" colado no painel viraria XSS em todo mundo que abre a aba.
  #
  # Ancorado nas DUAS pontas (\A…\z, não $): com âncora só no começo, um
  # "https://ok\njavascript:alert(1)" passa — $ casa em fim de LINHA. O \S+
  # fecha a mesma porta pelo outro lado, barrando o espaço e a quebra de linha.
  validates :github_url, :linkedin_url, :lattes_url, allow_blank: true,
            format: { with: %r{\Ahttps?://\S+\z}i, message: "precisa começar com http:// ou https://" }

  delegate :name, :discord_username, :email, to: :user

  def mandato_vigente
    mandatos.find_by(gestao: Gestao.vigente)
  end

  def foto_para_card
    foto.attached? ? foto : user.foto
  end

  # Títulos das ações participadas de VÁRIOS membros de uma vez:
  # { member_id => ["título", ...] }, cada lista já na ordem do card.
  #
  # Existe porque acoes_participadas custa 4 consultas POR MEMBRO — numa
  # listagem de 30 membros eram ~120 só para preencher três linhas de texto por
  # card. Aqui são 4 no total, independentemente de quantos membros vierem.
  #
  # Três consultas de vínculo (as três formas de participar) + uma de ações.
  # O join passa pelo detalhe: Projeto/Evento/Artigo têm has_one :acao, as: :detalhe.
  def self.titulos_de_acoes(members)
    ids = members.map(&:id).uniq
    return {} if ids.empty?

    pares = [
      Contribuicao.where(member_id: ids).joins(projeto: :acao).pluck(:member_id, "acoes.id"),
      EventoMembro.where(member_id: ids).joins(evento: :acao).pluck(:member_id, "acoes.id"),
      Autor.where(member_id: ids).joins(artigo: :acao).pluck(:member_id, "acoes.id")
    ].flatten(1)
    return {} if pares.empty?

    # Só publicadas, e na MESMA ordem de acoes_participadas (mais recente
    # primeiro), senão o card mostraria três títulos diferentes dos de antes.
    # A iteração é sobre ESTA lista ordenada, não sobre `pares` — os pares saem
    # agrupados por forma de participação (contribuição, evento, autoria), que
    # não tem nada a ver com data.
    ordenadas = Acao.publicadas.where(id: pares.map(&:last).uniq)
                    .order(created_at: :desc).pluck(:id, :titulo)

    membros_por_acao = pares.group_by(&:last).transform_values { |ps| ps.map(&:first).uniq }

    mapa = Hash.new { |h, k| h[k] = [] }
    ordenadas.each do |acao_id, titulo|
      membros_por_acao.fetch(acao_id, []).each { |member_id| mapa[member_id] << titulo }
    end
    mapa
  end

  # Ações publicadas em que o membro participou (RF-MEM): como contribuidor de
  # projeto, participante/organizador de evento ou autor de artigo.
  # Para LISTAGEM use titulos_de_acoes (em lote); esta aqui é para um membro só.
  def acoes_participadas
    projeto_ids = Contribuicao.where(member_id: id).select(:projeto_id)
    evento_ids  = EventoMembro.where(member_id: id).select(:evento_id)
    artigo_ids  = Autor.where(member_id: id).select(:artigo_id)
    ids = Acao.where(detalhe_type: "Projeto", detalhe_id: projeto_ids).ids +
          Acao.where(detalhe_type: "Evento",  detalhe_id: evento_ids).ids +
          Acao.where(detalhe_type: "Artigo",  detalhe_id: artigo_ids).ids
    Acao.publicadas.where(id: ids).order(created_at: :desc)
  end

  private

  def padrinho_nao_pode_ser_si_mesmo
    errors.add(:padrinho, "não pode ser o próprio membro") if padrinho_id.present? && padrinho_id == id
  end
end
