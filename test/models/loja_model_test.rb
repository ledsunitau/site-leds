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

  test "galeria aceita até 6 fotos e recusa a 7ª" do
    p = Produto.create!(nome: "Kit Fotos", preco: 10, modo_venda: "estoque",
                        status: "ativo", criador: members(:membro_comum))
    6.times { |i| p.galeria.attach(io: StringIO.new("x"), filename: "f#{i}.png", content_type: "image/png") }
    assert p.valid?, p.errors.full_messages.to_sentence

    p.galeria.attach(io: StringIO.new("x"), filename: "f7.png", content_type: "image/png")
    assert_not p.valid?
    assert p.errors[:galeria].any?
  end

  # --- Avaliacao: faixa da nota ---

  test "nota fora de 1..5 é inválida" do
    a = Avaliacao.new(produto: produtos(:camiseta), autor: users(:ana), nota: 6)
    assert_not a.valid?
    assert a.errors[:nota].any?
  end
end
