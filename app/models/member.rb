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

  # Foto institucional do card (RF-MEM-06); sem ela, o card usa a foto de
  # perfil do usuário (fallback em foto_para_card).
  has_one_attached :foto

  validates :user_id, uniqueness: true
  validate :padrinho_nao_pode_ser_si_mesmo

  delegate :name, :discord_username, to: :user

  def mandato_vigente
    mandatos.find_by(gestao: Gestao.vigente)
  end

  def foto_para_card
    foto.attached? ? foto : user.foto
  end

  private

  def padrinho_nao_pode_ser_si_mesmo
    errors.add(:padrinho, "não pode ser o próprio membro") if padrinho_id.present? && padrinho_id == id
  end
end
