require "test_helper"

# Regras de model da loja: settings (toggles), best-sellers com fallback,
# destaque e faixa da nota de avaliação.
class LojaModelTest < ActiveSupport::TestCase
  # --- Setting (key/value com defaults) ---

  test "loja nasce ativa e em modo direto por padrão (sem linha no banco)" do
    assert Setting.loja_ativa?
    assert_equal "direto", Setting.modo_pagamento
  end

  test "toggles persistem e modo inválido cai no default" do
    Setting.loja_ativa = false
    assert_not Setting.loja_ativa?

    Setting.modo_pagamento = "mercado_pago"
    assert_equal "mercado_pago", Setting.modo_pagamento

    Setting.modo_pagamento = "pix_magico" # valor inválido
    assert_equal "direto", Setting.modo_pagamento
  end

  # --- Produto: destaque + mais vendidos ---

  test "scope destaques traz só os marcados" do
    assert_empty Produto.destaques
    produtos(:camiseta).update!(destaque: true)
    assert_equal [ produtos(:camiseta) ], Produto.destaques.to_a
  end

  test "mais_vendidos completa com ativos quando ainda não houve vendas" do
    vitrine = Produto.mais_vendidos(6)
    assert_includes vitrine, produtos(:camiseta)
    assert_includes vitrine, produtos(:moletom)
    assert_not_includes vitrine, produtos(:caneca_antiga), "indisponível não entra na vitrine"
  end

  # Havia um teto de 6 fotos ("regra do display"). Não existe mais: o display
  # nunca precisou dele — a tira mostra 3 miniaturas e colapsa o resto em "+N".
  test "galeria não tem teto de quantidade" do
    p = Produto.create!(nome: "Kit Fotos", preco: 10, modo_venda: "estoque",
                        status: "ativo", criador: members(:membro_comum))
    12.times { |i| p.galeria.attach(io: StringIO.new("x"), filename: "f#{i}.png", content_type: "image/png") }

    assert p.valid?, p.errors.full_messages.to_sentence
    assert_equal 12, p.galeria.attachments.size
  end

  # A galeria não tinha validação NENHUMA de tipo ou tamanho — só a imagem
  # principal tinha. Era upload de usuário entrando sem passar por porta.
  test "galeria recusa arquivo que não é imagem e arquivo grande demais" do
    p = Produto.create!(nome: "Kit Ruim", preco: 10, modo_venda: "estoque",
                        status: "ativo", criador: members(:membro_comum))

    p.galeria.attach(io: StringIO.new("%PDF-1.4"), filename: "manual.pdf", content_type: "application/pdf")
    assert_not p.valid?
    assert_match(/JPEG, PNG, WebP ou SVG/, p.errors[:galeria].to_sentence)

    p.galeria.detach
    p.galeria.attach(io: StringIO.new("x" * 6.megabytes), filename: "enorme.png", content_type: "image/png")
    assert_not p.valid?
    assert_match(/5 MB/, p.errors[:galeria].to_sentence)
  end

  # O seed usa SVG como stand-in das fotos de demonstração, e o Active Storage
  # serve svg+xml como binário — mesmo motivo do logo de parceiro.
  test "galeria aceita SVG" do
    p = Produto.create!(nome: "Kit SVG", preco: 10, modo_venda: "estoque",
                        status: "ativo", criador: members(:membro_comum))
    p.galeria.attach(io: StringIO.new("<svg/>"), filename: "logo.svg", content_type: "image/svg+xml")

    assert p.valid?, p.errors.full_messages.to_sentence
  end

  # Uma mensagem por problema, não uma por arquivo.
  test "várias fotos erradas não repetem a mesma mensagem" do
    p = Produto.create!(nome: "Kit Repetido", preco: 10, modo_venda: "estoque",
                        status: "ativo", criador: members(:membro_comum))
    3.times { |i| p.galeria.attach(io: StringIO.new("x"), filename: "f#{i}.pdf", content_type: "application/pdf") }

    assert_not p.valid?
    assert_equal 1, p.errors[:galeria].size
  end

  # --- Avaliacao: faixa da nota ---

  test "nota fora de 1..5 é inválida" do
    a = Avaliacao.new(produto: produtos(:camiseta), autor: users(:ana), nota: 6)
    assert_not a.valid?
    assert a.errors[:nota].any?
  end
end
