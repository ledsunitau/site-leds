# Tags permitidas na renderização do corpo (Action Text).
#
# A lista padrão foi desenhada para o que o Trix produz, e o Trix não faz tabela.
# Com o modo markdown (RF-NOV-04) o corpo passa a receber markup que o editor
# rico nunca gerou: `| a | b |` vira uma <table> de verdade — e sem estas tags o
# sanitizador a removia INTEIRA, em silêncio. O autor via a tabela no fonte, não
# via nada na página publicada e não recebia erro nenhum.
#
# O resto do que o markdown gera (h1-h6, ul/ol/li, pre, code, blockquote, hr,
# strong, em, a, img) já está no padrão do rails-html-sanitizer.
#
# ATENÇÃO à forma de escrever isto. `ContentHelper.allowed_tags` é nil por
# padrão, e nil NÃO significa "lista vazia": significa "use o fallback", que o
# gem monta em sanitizer_allowed_tags. Partir de `allowed_tags.to_a` (o caminho
# óbvio) dá `[]`, e a atribuição vira uma lista SÓ com as tags daqui — o corpo
# inteiro passa a ser despido, parágrafo e negrito inclusive. Por isso a base
# reproduz o fallback do gem, em vez de ler o accessor.
Rails.application.config.to_prepare do
  padrao = ActionText::ContentHelper.sanitizer.class.allowed_tags.to_a +
           [ ActionText::Attachment.tag_name, "figure", "figcaption" ]

  ActionText::ContentHelper.allowed_tags =
    padrao | %w[table thead tbody tfoot tr th td caption]
end
