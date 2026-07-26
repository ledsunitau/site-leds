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
  has_one_attached :foto

  validates :user_id, uniqueness: true
  validate :padrinho_nao_pode_ser_si_mesmo

  delegate :name, :discord_username, :email, to: :user

  def mandato_vigente
    mandatos.find_by(gestao: Gestao.vigente)
  end

  def foto_para_card
    foto.attached? ? foto : user.foto
  end

  # Ações publicadas em que o membro participou (RF-MEM): como contribuidor de
  # projeto, participante/organizador de evento ou autor de artigo. O card
  # mostra os títulos (3 + "mais ações"). ponytail: consulta por membro (N+1 na
  # listagem) — ok com poucos membros; se crescer, pré-carregar em lote.
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
