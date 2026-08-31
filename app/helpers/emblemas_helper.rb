# Renderização de emblema, rank e elo (RF-EMB). O ícone é markup guardado no
# banco, então tudo que sai por aqui passa pelo sanitizer — os models já
# sanitizam na gravação, e repetir na leitura cobre linha alterada por console
# ou SQL direto.
module EmblemasHelper
  # SVG pronto para inserir. `sanitize` devolve string segura (html_safe).
  def emblema_svg(fonte)
    sanitize fonte.icone_svg, tags: Emblema::TAGS_SVG, attributes: Emblema::ATRIBUTOS_SVG
  end

  # A fonte usa as cores do próprio SVG? Emblema e Elo têm a coluna; o rank e a
  # prévia do formulário passam por aqui sem ter, então responde false em vez
  # de estourar.
  def svg_original?(fonte)
    fonte.respond_to?(:svg_original?) && fonte.svg_original?
  end

  # Classe do wrapper para quem renderiza o SVG fora do emblema_icone (a prévia
  # do formulário e a escada de ranks). Mantém o escape num lugar só.
  def emblema_svg_classe(fonte)
    "svg-original" if svg_original?(fonte)
  end

  # Forma genérica para prever cor e efeito de um RANK, que não tem desenho
  # próprio (o desenho é sempre do emblema; o rank só troca cor e animação).
  MEDALHA = '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">' \
            '<path d="M12 2l2.6 5.6 6.1.8-4.5 4.2 1.2 6L12 15.6 6.6 18.6l1.2-6L3.3 8.4l6.1-.8z"/>' \
            "</svg>".html_safe
  def medalha = MEDALHA

  # Ícone completo: wrapper com a cor e a classe do efeito. `tamanho` é uma das
  # variações do CSS (mini/sm/md/lg). `bloqueado` desenha a silhueta.
  #
  # `vinculo` (o EmblemaUsuario) manda quando existe: num escalonável, quem
  # define cor e efeito é o RANK alcançado, não o emblema — é assim que se lê
  # "o mesmo maratonista, agora em ouro".
  def emblema_icone(emblema, tamanho: "md", bloqueado: false, vinculo: nil)
    cor = vinculo&.cor_efetiva || emblema.cor
    efeito = vinculo&.efeito_efetivo || emblema.efeito

    classes = [ "emblema", "emblema-#{tamanho}" ]
    classes << "emblema-fx-#{efeito}" unless bloqueado || efeito == "nenhum"
    classes << "bloqueado" if bloqueado
    # Desliga o repinte do CSS: o desenho sai com as cores próprias. A `cor`
    # continua sendo aplicada como --emblema-cor porque os efeitos (neon,
    # brilho) tiram o brilho dela — só o preenchimento das formas é que passa
    # a ser do SVG. Ver .emblema:not(.svg-original) no application.css.
    classes << "svg-original" if svg_original?(emblema)

    tag.span(emblema_svg(emblema), class: classes,
             style: "--emblema-cor: #{cor}", title: emblema.nome)
  end

  # Ícone do elo. Sem SVG cadastrado vira a inicial do nome — um elo sem
  # desenho ainda precisa aparecer no perfil.
  #
  # `svg_original` vale aqui como no emblema: ligado, o desenho sai com as cores
  # próprias e a `cor` do elo fica só para o resto (ranking, nome do degrau e o
  # brilho dos efeitos). A inicial, quando não há SVG, é sempre pintada — não é
  # arte de ninguém, é texto.
  def elo_icone(elo, tamanho: "md")
    classes = [ "emblema", "emblema-#{tamanho}", "elo-icone" ]
    classes << "emblema-fx-#{elo.efeito}" unless elo.efeito == "nenhum"
    conteudo = elo.icone_svg.present? ? emblema_svg(elo) : tag.strong(elo.nome.first)
    classes << "svg-original" if elo.icone_svg.present? && svg_original?(elo)

    tag.span(conteudo, class: classes, style: "--emblema-cor: #{elo.cor}", title: elo.nome)
  end

  # Nome do usuário pintado com o COSMÉTICO que ele escolheu vestir — não com o
  # emblema em destaque, que hoje é só vitrine. Sem cosmético, o nome fica
  # branco, como o de qualquer um.
  #
  # Fonte única: o nome aparece em post, avaliação, drawer e perfil, e a pintura
  # não pode divergir entre eles. `fallback` cobre autor apagado (LGPD): "LEDS"
  # na novidade, "Anônimo" na avaliação — cada tela mantém o rótulo que já usava.
  def nome_com_emblema(user, classe: nil, fallback: "Usuário")
    pintura = pintura_de(user, :emblema_nome)
    return tag.span(user&.name.presence || fallback, class: classe) if pintura.nil?

    tag.span(user.name, class: [ classe, "nome-emblema", "cosm-#{pintura.cosmetico_movimento}" ].compact,
             style: estilo_do_cosmetico(pintura))
  end

  # Anel do avatar, com o mesmo cosmético. Usado dentro de shared/_avatar, que é
  # o ponto por onde todo avatar do site passa.
  def anel_do_emblema(user)
    pintura = pintura_de(user, :emblema_halo)
    return {} if pintura.nil?

    { class: "avatar-anel cosm-#{pintura.cosmetico_movimento}",
      style: estilo_do_cosmetico(pintura) }
  end

  # Só o movimento e as variáveis, SEM a borda em gradiente. É o que o botão do
  # header precisa: lá quem desenha o anel é o ::before dele, não o avatar.
  def halo_do_header(user)
    pintura = pintura_de(user, :emblema_halo)
    return {} if pintura.nil?

    { class: "tem-halo cosm-#{pintura.cosmetico_movimento}",
      style: estilo_do_cosmetico(pintura) }
  end

  # As variáveis que o CSS consome: o gradiente pronto, a lista de cores solta
  # (o anel do header monta um conic-gradient com ela) e a duração.
  def estilo_do_cosmetico(emblema)
    [ "--emblema-grad: #{emblema.cosmetico_css}",
      "--emblema-cores: #{emblema.cosmetico_cores_fechadas}",
      "--emblema-vel: #{emblema.cosmetico_velocidade}s" ].join("; ")
  end

  # "Raro · 7,2% dos usuários". Separador explícito: o pt-BR.yml do projeto não
  # traz a árvore `number:`, então o default do Rails ainda é o ponto (mesmo
  # motivo do preco_br no LojaHelper).
  def raridade_label(emblema)
    "#{emblema.raridade_label} · #{percentual_br(emblema.percentual)}% dos usuários"
  end

  def percentual_br(valor) = format("%.1f", valor).tr(".", ",")

  # Quanto falta para o próximo degrau, em fração de 0..100 para a barra.
  def pct_do_progresso(atual, alvo)
    return 0 if alvo.to_i <= 0

    [ atual.to_i * 100 / alvo.to_i, 100 ].min
  end

  private

  # A pintura é do EMBLEMA, não do rank alcançado — então sai direto do
  # belongs_to, sem consulta ao vínculo. (Era o que exigia memoização antes,
  # quando a cor vinha do rank.) `slot` é :emblema_nome ou :emblema_halo.
  def pintura_de(user, slot)
    emblema = user&.public_send(slot)
    emblema if emblema&.cosmetico?
  end
end
