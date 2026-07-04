# Regras de upload de foto (perfil de usuário e foto institucional do
# membro): só imagem web, tamanho limitado — o arquivo é servido público.
module FotoValidavel
  extend ActiveSupport::Concern

  TIPOS = %w[image/jpeg image/png image/webp].freeze
  TAMANHO_MAX = 5.megabytes

  included do
    validate :foto_deve_ser_imagem_pequena
  end

  private

  def foto_deve_ser_imagem_pequena
    return unless foto.attached?

    errors.add(:foto, "deve ser JPEG, PNG ou WebP") unless foto.content_type.in?(TIPOS)
    errors.add(:foto, "deve ter no máximo 5 MB") if foto.byte_size > TAMANHO_MAX
  end
end
