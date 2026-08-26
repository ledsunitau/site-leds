# Regras de upload de imagem (fotos, thumbnails, ícones, imagem de produto):
# só formatos web, tamanho limitado.
#
# ATENÇÃO ao servir: a URL sai por rails_blob_path (FotoUrl), rota do Active
# Storage que NÃO passa pelo Devise. O signed_id não é adivinhável — quem receber
# o link lê o arquivo sem sessão. Isso é indiferente para o que já é público
# (membro, post, parceiro), mas a loja exige login para LER (RN-17): o JSON está
# protegido, o byte da imagem não.
# DECISÃO (deploy): NÃO gatear o byte. Membro/post/produto passam pelas MESMAS
# rotas do Active Storage; gatear só produto exigiria proxy mode + rota autenticada
# custom por anexo. Custo alto para baixa sensibilidade (fotos de produto, catálogo
# já protegido, signed_id não-enumerável). Alavanca se um dia importar: proxy mode
# autenticado só para as imagens da loja.
#
#   include ImagemValidavel
#   valida_imagem :thumbnail
module ImagemValidavel
  extend ActiveSupport::Concern

  TIPOS = %w[image/jpeg image/png image/webp].freeze
  TAMANHO_MAX = 5.megabytes

  # Opções COMUNS a toda variante do site — só as medidas mudam por anexo.
  # Ficam aqui porque divergir é o modo de falha real: uma variante esquecida em
  # JPEG ou sem preprocessed passa despercebida até virar peso em produção.
  #
  #   has_one_attached :foto do |anexo|
  #     anexo.variant :avatar, resize_to_limit: [96, 96], **ImagemValidavel::VARIANTE
  #   end
  #
  # preprocessed: gera no upload (job do Solid Queue) em vez de na primeira
  # visita — quem abre a página não paga o processamento. Registro antigo, que
  # não tem a variante, gera sob demanda no primeiro acesso e cacheia.
  # resize_to_limit: nunca faz upscale e preserva proporção, então uma foto menor
  # que o limite passa intacta em vez de ser esticada.
  # webp é seguro: o allow_browser :modern do ApplicationController já o exige.
  VARIANTE = { format: :webp, saver: { quality: 80 }, preprocessed: true }.freeze

  class_methods do
    # tipos:/formatos: permitem casos como logo de parceiro (aceita SVG) sem
    # afrouxar as demais imagens (foto, thumbnail, ícone) — que seguem raster.
    def valida_imagem(nome, tipos: TIPOS, formatos: "JPEG, PNG ou WebP")
      validate do
        anexo = public_send(nome)
        next unless anexo.attached?

        errors.add(nome, "deve ser #{formatos}") unless anexo.content_type.in?(tipos)
        errors.add(nome, "deve ter no máximo 5 MB") if anexo.byte_size > TAMANHO_MAX
      end
    end
  end
end
