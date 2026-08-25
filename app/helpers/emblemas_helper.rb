# Renderização de emblema, rank e elo (RF-EMB). O ícone é markup guardado no
# banco, então tudo que sai por aqui passa pelo sanitizer — os models já
# sanitizam na gravação, e repetir na leitura cobre linha alterada por console
# ou SQL direto.
module EmblemasHelper
  # SVG pronto para inserir. `sanitize` devolve string segura (html_safe).
  def emblema_svg(fonte)
    sanitize fonte.icone_svg, tags: Emblema::TAGS_SVG, attributes: Emblema::ATRIBUTOS_SVG
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

    tag.span(emblema_svg(emblema), class: classes,
             style: "--emblema-cor: #{cor}", title: emblema.nome)
  end

  # Ícone do elo. Sem SVG cadastrado vira a inicial do nome — um elo sem
  # desenho ainda precisa aparecer no perfil.
  def elo_icone(elo, tamanho: "md")
    classes = [ "emblema", "emblema-#{tamanho}", "elo-icone" ]
    classes << "emblema-fx-#{elo.efeito}" unless elo.efeito == "nenhum"
    conteudo = elo.icone_svg.present? ? emblema_svg(elo) : tag.strong(elo.nome.first)

    tag.span(conteudo, class: classes, style: "--emblema-cor: #{elo.cor}", title: elo.nome)
  end

  # Nome do usuário pintado com a cor do emblema em destaque. Fonte única — o
  # nome aparece em post, avaliação, drawer e perfil, e a cor não pode divergir.
  # `fallback` cobre autor apagado (LGPD): "LEDS" na novidade, "Anônimo" na
  # avaliação — cada tela mantém o rótulo que já usava.
  def nome_com_emblema(user, classe: nil, fallback: "Usuário")
    return tag.span(user&.name.presence || fallback, class: classe) if user&.emblema_destaque.nil?

    tag.span(user.name, class: [ classe, "nome-emblema" ].compact,
             style: "--emblema-cor: #{cor_do_destaque(user)}")
  end

  # Classe do anel do avatar. Usada dentro de shared/_avatar, que é o ponto por
  # onde todo avatar do site passa.
  def anel_do_emblema(user)
    emblema = user&.emblema_destaque
    return {} if emblema.nil?

    { class: "avatar-anel avatar-fx-#{efeito_do_destaque(user)}",
      style: "--emblema-cor: #{cor_do_destaque(user)}" }
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

  # O destaque de um escalonável usa a cor do RANK alcançado, que mora no
  # vínculo. Memoizado por request e por usuário: sem isso, cada nome numa lista
  # de novidades custaria duas consultas (o nome pintado e o anel do avatar).
  def vinculo_do_destaque(user)
    return nil if user&.emblema_destaque_id.nil?

    @vinculos_do_destaque ||= {}
    @vinculos_do_destaque.fetch(user.id) do
      @vinculos_do_destaque[user.id] =
        EmblemaUsuario.includes(nivel: :rank)
                      .find_by(user_id: user.id, emblema_id: user.emblema_destaque_id)
    end
  end

  def cor_do_destaque(user)
    vinculo_do_destaque(user)&.cor_efetiva || user.emblema_destaque.cor
  end

  def efeito_do_destaque(user)
    vinculo_do_destaque(user)&.efeito_efetivo || user.emblema_destaque.efeito
  end
end
