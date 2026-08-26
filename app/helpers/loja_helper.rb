module LojaHelper
  # Imagem do produto: usa o anexo se houver; senão o placeholder do código
  # (mesma ideia do card_image_url, mas Produto tem `imagem`, não `thumbnail`).
  def produto_imagem_url(produto)
    FotoUrl.para(produto.imagem, :card) || image_path("card-placeholder.svg")
  end

  # URL de uma foto da galeria (Attached::One da principal ou Attachment das
  # extras — ver Produto#fotos). :card nas miniaturas, :full na foto grande e no
  # lightbox, que é onde a pessoa amplia e o pixel importa.
  def foto_url(foto, variante = :full)
    FotoUrl.para(foto, variante) || image_path("card-placeholder.svg")
  end

  # Preço em reais (o site não tem locale pt-BR configurado, então formato explícito).
  def preco_br(valor)
    number_to_currency(valor, unit: "R$ ", separator: ",", delimiter: ".")
  end

  # Cores de accent dos cards da loja, no ciclo do Figma (verde, vermelho, azul).
  LOJA_ACCENTS = [ "var(--leds-green)", "var(--leds-red)", "var(--leds-blue)" ].freeze

  def loja_accent(indice)
    LOJA_ACCENTS[indice % LOJA_ACCENTS.size]
  end

  # Estrelas com preenchimento FRACIONÁRIO segundo a nota (0..5): 4.6 mostra
  # 4 estrelas e um pouco, não 5. Camada de trás cinza + camada da frente
  # amarela cortada na porcentagem da nota. `nota` nil vira 0.
  def estrelas(nota)
    pct = ((nota.to_f / 5.0) * 100).clamp(0, 100).round(1)
    tag.span(class: "stars", role: "img", "aria-label": "#{nota || 0} de 5") do
      safe_join([
        tag.span("★★★★★", class: "stars-bg", "aria-hidden": true),
        tag.span("★★★★★", class: "stars-fg", style: "width: #{pct}%", "aria-hidden": true)
      ])
    end
  end
end
