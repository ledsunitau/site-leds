module ApplicationHelper
  # Iniciais para o avatar quando não há foto (ex.: "Vinicius Renó" -> "VR").
  def iniciais(nome)
    partes = nome.to_s.split
    partes.first(2).map { |p| p[0] }.join.upcase.presence || "?"
  end

  # Rótulo amigável do papel de acesso (User#role).
  PAPEL_LABEL = {
    "comunidade" => "Comunidade", "escritor" => "Escritor", "parceiro" => "Parceiro",
    "membro" => "Membro", "diretoria" => "Diretoria", "presidencia" => "Presidência"
  }.freeze

  def papel_label(role)
    PAPEL_LABEL[role.to_s] || role.to_s.capitalize
  end

  # URL da MESMA página com alguns parâmetros trocados, preservando os outros —
  # é o que faz chip, busca e pager se combinarem em vez de um zerar o outro.
  # Valor em branco é REMOVIDO: é assim que o chip "Todos" (tipo: nil) limpa o
  # filtro, e é o que mantém a URL curta em vez de arrastar `?tipo=&q=`.
  #
  # Montado na mão em vez de url_for: url_for interpreta chaves como :controller
  # e :action, e aqui o que se quer é literalmente a query string atual mais um
  # delta.
  def url_com(**novos)
    query = request.query_parameters.merge(novos.transform_keys(&:to_s))
                   .reject { |_, valor| valor.blank? }
    query.any? ? "#{request.path}?#{query.to_query}" : request.path
  end
end
