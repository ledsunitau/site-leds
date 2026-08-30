# Variantes de imagem do Active Storage.
#
# Registro NOVO já nasce com variante: os anexos são declarados com
# `preprocessed: true`, que enfileira o ActiveStorage::TransformJob no upload.
#
# Registro ANTIGO (subido antes da variante existir, ou depois de ela mudar de
# tamanho — mudar as medidas muda a chave de variação e invalida as antigas) não
# tem nenhuma. Ele não quebra: o Active Storage gera sob demanda. Mas a geração
# acontece DENTRO do request do primeiro visitante, esperando o libvips. Numa
# página de catálogo isso é uma dúzia de conversões em série.
#
# Esta task antecipa esse trabalho. É idempotente (variante existente é
# reaproveitada), então rodar de novo é barato e seguro.
#
#   bin/rails imagens:preparar_variantes     # ou `kamal variantes` em produção
namespace :imagens do
  # Descobre os anexos pelos PRÓPRIOS models, em vez de manter uma lista aqui.
  #
  # Antes esta lista era escrita à mão e já nasceu com o defeito óbvio: quando
  # User#foto ganhou a variante :retrato, a lista continuou dizendo [:avatar] e o
  # backfill teria gerado metade — silenciosamente, com o custo caindo no
  # primeiro visitante. Derivar da reflection elimina a possibilidade.
  #
  # Anexo sem variante nomeada (os ícones SVG de Tecnologia/Tema) fica de fora
  # sozinho, porque não há o que pré-gerar.
  def self.anexos_com_variantes
    Rails.application.eager_load!

    ApplicationRecord.descendants.flat_map do |model|
      model.attachment_reflections.filter_map do |anexo, reflection|
        variantes = reflection.named_variants.keys
        [ model, anexo, variantes ] if variantes.any?
      end
    end
  end

  desc "Gera as variantes de imagem que ainda não existem (idempotente)"
  task preparar_variantes: :environment do
    total = 0
    falhas = 0

    anexos_com_variantes.each do |model, anexo, variantes|
      puts "#{model}##{anexo}: #{variantes.join(', ')}"

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
            warn "  ! #{model}##{registro.id} #{anexo}/#{variante}: #{e.class} #{e.message}"
          end
        end
      end
    end

    puts "#{total} variante(s) prontas#{falhas.positive? ? ", #{falhas} falha(s) — ver acima" : ""}"
  end
end
