module AcoesHelper
  # Normaliza um nome de tecnologia para um "slug" comparável:
  # "C++"->cpp, "C#"->csharp, ".NET"->net, "Node.js"->nodejs, "Ruby on Rails"->rubyonrails.
  def self.slug_tec(nome)
    nome.to_s.downcase.gsub("++", "pp").gsub("#", "sharp").gsub("+", "p").gsub(/[^a-z0-9]/, "")
  end

  # Descobre TODOS os ícones em app/assets/images/tech/*.svg automaticamente:
  # basta adicionar o arquivo e cadastrar a tecnologia com o nome certo no banco.
  # Mapa: slug normalizado => nome real do arquivo (ex.: "csharp" => "c_sharp").
  TECH_ICONS = Dir.glob(Rails.root.join("app/assets/images/tech/*.svg")).each_with_object({}) do |f, h|
    base = File.basename(f, ".svg")
    h[slug_tec(base)] = base
  end.freeze

  # Apelidos de nomes que não batem 1:1 com o arquivo.
  TECH_ALIAS = {
    "js" => "javascript", "reactjs" => "react", "py" => "python",
    "go" => "golang", "golanguage" => "golang",
    "node" => "nodejs",
    "net" => "dotnet", "dotnetcore" => "dotnet", "dotnetframework" => "dotnet",
    "postgres" => "postgre", "postgresql" => "postgre", "psql" => "postgre",
    "rubyonrails" => "rails", "ror" => "rails",
    "tailwindcss" => "tailwind",
    "cplusplus" => "cpp",
    "amazonwebservices" => "aws",
    "googlecloud" => "gcp", "googlecloudplatform" => "gcp",
    "microsoftazure" => "azure"
  }.freeze

  # Data do card conforme o tipo: evento é dia marcado, então vai por extenso
  # ("12 mai 2026") — o dia é o que importa nele. Projeto/artigo mostram "em dev"
  # enquanto não finalizados, senão só o mês/ano de finalização, que é a precisão
  # que uma conclusão tem.
  def data_da_acao(acao)
    d = acao.detalhe
    case d
    when Evento then data_por_extenso(d.data_inicio)
    when Projeto, Artigo then d.finalizado? ? mes_ano(d.data_finalizacao) : "em dev"
    else ""
    end
  end

  # Participantes com foto: membros (projeto/evento) ou autores (artigo).
  def participantes_da_acao(acao)
    case acao.detalhe
    when Projeto, Evento
      acao.detalhe.membros.map { |m| { nome: m.name, foto: foto_de_membro(m) } }
    when Artigo
      acao.detalhe.autores.map do |a|
        { nome: a.nome, foto: a.member ? foto_de_membro(a.member) : image_path("avatar-default.svg") }
      end
    else []
    end
  end

  # `variante` porque os dois consumos têm ordens de grandeza diferentes: os
  # participantes do card de ação são círculos de 34px (:avatar), e a foto do
  # card em /membros é 300×360 (:retrato). Servir :avatar aos dois foi o bug da
  # foto pixelada — o default aqui é o caso pequeno, que é a maioria.
  def foto_de_membro(member, variante = :avatar)
    FotoUrl.para(member.foto_para_card, variante) || image_path("avatar-default.svg")
  end

  # Ícone de tecnologia/tema: ícone salvo no banco > ícone empacotado pelo nome
  # > pílula com o nome (fallback). `title` mostra o nome no hover (tag HTML nativa).
  def icone_ou_pill(record)
    if record.icone.attached?
      image_tag rails_blob_path(record.icone, only_path: true), alt: record.nome, title: record.nome, class: "tech-ico"
    elsif (arquivo = icone_de_tecnologia(record.nome))
      image_tag "tech/#{arquivo}.svg", alt: record.nome, title: record.nome, class: "tech-ico"
    else
      content_tag :span, record.nome, class: "tech-pill", title: record.nome
    end
  end

  # Nome do arquivo do ícone para uma tecnologia, ou nil se não houver.
  def icone_de_tecnologia(nome)
    slug = AcoesHelper.slug_tec(nome)
    slug = TECH_ALIAS[slug] || slug
    TECH_ICONS[slug]
  end

  # Link do Google Maps a partir do texto do local do evento.
  def maps_url(local)
    "https://www.google.com/maps/search/?api=1&query=#{CGI.escape(local.to_s)}"
  end
end
