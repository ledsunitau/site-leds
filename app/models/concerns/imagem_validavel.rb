# Regras de upload de imagem (fotos, thumbnails, ícones, imagem de produto):
# só formatos web, tamanho limitado.
#
# ATENÇÃO ao servir: a URL sai por rails_blob_path (FotoUrl), rota do Active
# Storage que NÃO passa pelo Devise. O signed_id não é adivinhável, mas também
# não expira — quem receber o link lê o arquivo sem sessão. Isso é indiferente
# para o que já é público (membro, post, parceiro), mas a loja exige login para
# LER (RN-17): o JSON está protegido, o byte da imagem não. Se isso incomodar,
# a alavanca é urls_expire_in / entrega autenticada, na branch de deploy (R2).
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
