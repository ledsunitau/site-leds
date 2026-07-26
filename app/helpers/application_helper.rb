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
end
