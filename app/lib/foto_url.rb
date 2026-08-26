# URL de foto. Sempre caminho RELATIVO (only_path): URL absoluta dependeria do
# host da requisição e, dentro de payloads cacheados (grafo/geneograma),
# congelaria o host do primeiro visitante.
#
# `variante` é o nome de uma variante declarada no has_one_attached do model
# (:avatar, :card, :full — ver ImagemValidavel::VARIANTE). Sem ela sai o
# ORIGINAL, que é o que a gestão subiu: uma foto de celular de 4MB dentro de um
# avatar de 40px. Passar a variante é a regra, omitir é a exceção.
#
# Cai no original quando o anexo não é processável (SVG, PDF): variable? é falso
# lá, e um logo vetorial não precisa de resize mesmo.
module FotoUrl
  extend self
  include Rails.application.routes.url_helpers

  # url_helpers dentro de um módulo solto (sem controller/view por baixo) exige
  # que o includer forneça isto. rails_blob_path passava sem, mas
  # rails_representation_path levanta NameError. Vazio porque toda saída daqui é
  # only_path: nenhum host entra na conta.
  def default_url_options = {}

  def para(foto, variante = nil)
    return nil if foto.nil?
    # Attached::One (user.foto) responde attached?; ActiveStorage::Attachment,
    # que é o que Produto#fotos devolve da galeria, NÃO — ele já é um anexo que
    # existe. Sem este respond_to? a galeria estoura NoMethodError.
    return nil if foto.respond_to?(:attached?) && !foto.attached?

    if variante && foto.variable?
      rails_representation_path(foto.variant(variante), only_path: true)
    else
      rails_blob_path(foto, only_path: true)
    end
  end
end
