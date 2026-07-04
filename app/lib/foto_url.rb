# URL de foto para respostas JSON. Sempre caminho RELATIVO (only_path):
# URL absoluta dependeria do host da requisição e, dentro de payloads
# cacheados (grafo/geneograma), congelaria o host do primeiro visitante.
module FotoUrl
  extend self
  include Rails.application.routes.url_helpers

  def para(foto)
    foto.attached? ? rails_blob_path(foto, only_path: true) : nil
  end
end
