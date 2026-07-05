# Regras de upload de imagem pública (fotos, thumbnails, ícones):
# só formatos web, tamanho limitado — todo anexo aqui é servido público.
#
#   include ImagemValidavel
#   valida_imagem :thumbnail
module ImagemValidavel
  extend ActiveSupport::Concern

  TIPOS = %w[image/jpeg image/png image/webp].freeze
  TAMANHO_MAX = 5.megabytes

  class_methods do
    def valida_imagem(nome)
      validate do
        anexo = public_send(nome)
        next unless anexo.attached?

        errors.add(nome, "deve ser JPEG, PNG ou WebP") unless anexo.content_type.in?(TIPOS)
        errors.add(nome, "deve ter no máximo 5 MB") if anexo.byte_size > TAMANHO_MAX
      end
    end
  end
end
