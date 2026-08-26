# Variantes de imagem do Active Storage (:avatar, :card, :full).
#
# Registro NOVO já nasce com variante: os anexos são declarados com
# `preprocessed: true`, que enfileira o ActiveStorage::TransformJob no upload.
#
# Registro ANTIGO (subido antes das variantes existirem) não tem nenhuma. Ele
# não quebra — o Active Storage gera sob demanda —, mas a geração acontece
# DENTRO do request do primeiro visitante, que fica esperando o libvips. Numa
# página de catálogo isso é uma dúzia de conversões em série.
#
# Esta task antecipa esse trabalho. É idempotente (variante existente é
# reaproveitada), então rodar de novo é barato e seguro.
#
#   bin/rails imagens:preparar_variantes     # ou `kamal variantes` em produção
namespace :imagens do
  # [model, anexo, [variantes]] — espelha os has_one/many_attached dos models.
  # Tecnologia e Tema ficam de fora: os ícones são SVG, que não é `variable?`.
  ANEXOS = [
    [ "User",      :foto,      %i[avatar] ],
    [ "Member",    :foto,      %i[avatar] ],
    [ "Acao",      :thumbnail, %i[card] ],
    [ "Post",      :thumbnail, %i[card] ],
    [ "Produto",   :imagem,    %i[card full] ],
    [ "Produto",   :galeria,   %i[card full] ],
    [ "Parceiro",  :logo,      %i[card] ]
  ].freeze

  desc "Gera as variantes de imagem que ainda não existem (idempotente)"
  task preparar_variantes: :environment do
    total = 0
    falhas = 0

    ANEXOS.each do |nome_model, anexo, variantes|
      model = nome_model.constantize

      model.find_each do |registro|
        # has_many_attached devolve uma coleção; has_one_attached, um só.
        alvos = Array(registro.public_send(anexo).then { |a| a.respond_to?(:attachments) ? a.attachments : a })
        alvos.each do |alvo|
          next unless alvo.respond_to?(:variable?) && alvo.variable?

          variantes.each do |variante|
            alvo.variant(variante).processed
            total += 1
          rescue StandardError => e
            # Um blob corrompido não pode abortar a fila inteira: registra e segue.
            falhas += 1
            warn "  ! #{nome_model}##{registro.id} #{anexo}/#{variante}: #{e.class} #{e.message}"
          end
        end
      end
    end

    puts "#{total} variante(s) prontas#{falhas.positive? ? ", #{falhas} falha(s) — ver acima" : ""}"
  end
end
