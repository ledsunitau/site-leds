require "test_helper"

class ProdutoTest < ActiveSupport::TestCase
  test "preco_atual usa a promoção quando existe (RF-LOJ-10)" do
    # BigDecimal, não Float: dinheiro não passa por binário. assert_equal com
    # literal Float passaria mesmo se preco_atual virasse Float um dia.
    assert_equal BigDecimal("49.90"), produtos(:camiseta).preco_atual, "com promoção"
    assert_equal BigDecimal("150.00"), produtos(:moletom).preco_atual, "sem promoção, o cheio"
  end

  test "promoção não pode ser maior que o preço (dígito trocado viraria cobrança)" do
    produto = produtos(:camiseta) # preco 60.00
    produto.preco_promocional = 599.00
    assert_not produto.valid?
    assert produto.errors[:preco_promocional].any?

    produto.preco_promocional = 60.00 # igual ao preço: permitido
    assert produto.valid?
  end

  test "sob demanda exige quantidade_alvo — sem meta não há o que disparar" do
    produto = Produto.new(nome: "X", modo_venda: "sob_demanda", preco: 10)
    assert_not produto.valid?
    assert produto.errors[:quantidade_alvo].any?

    produto.quantidade_alvo = 5
    assert produto.valid?
  end

  test "modo estoque não precisa de meta; a troca de modo é reversível (RN-09)" do
    produto = produtos(:camiseta)
    assert_nil produto.quantidade_alvo
    assert produto.valid?

    # estoque → sob_demanda exige a meta
    produto.modo_venda = "sob_demanda"
    assert_not produto.valid?
    produto.quantidade_alvo = 30
    assert produto.valid?

    # e volta
    produto.modo_venda = "estoque"
    assert produto.valid?
  end

  test "enums inválidos são 422, não 500" do
    produto = Produto.new(nome: "X", preco: 10, modo_venda: "leilao", status: "sumido")
    assert_not produto.valid?
    assert produto.errors[:modo_venda].any?
    assert produto.errors[:status].any?
  end

  test "preço negativo é inválido" do
    assert_not Produto.new(nome: "X", preco: -1).valid?
    assert_not Produto.new(nome: "X", preco: 10, preco_promocional: -1).valid?
  end

  test "cadastro e edição são auditados (RF-LOJ-09/RN-13)" do
    assert_difference "PaperTrail::Version.where(item_type: 'Produto').count", 1 do
      PaperTrail.request(whodunnit: users(:membro_user).id.to_s) do
        produtos(:camiseta).update!(preco: 70)
      end
    end
    assert_equal users(:membro_user).id.to_s, produtos(:camiseta).versions.last.whodunnit
  end

  test "SKU é único quando preenchido, mas várias variantes podem não ter" do
    duplicada = Variante.new(produto: produtos(:moletom), nome: "Outra", sku: "CAM-M")
    assert_not duplicada.valid?

    assert_difference "Variante.count", 1 do
      produtos(:moletom).variantes.create!(nome: "Sem sku também", estoque: 0)
    end
  end

  test "SKU vazio vira nil — senão fura o allow_nil e estoura o índice parcial (500)" do
    a = produtos(:moletom).variantes.create!(nome: "P", sku: "", estoque: 0)
    assert_nil a.sku, "'' normalizado para nil"

    # dois SKUs vazios convivem: nil não entra no índice (WHERE sku IS NOT NULL)
    assert_difference "Variante.count", 1 do
      produtos(:moletom).variantes.create!(nome: "GG", sku: "", estoque: 0)
    end
  end

  test "validações de variante espelham os CHECKs (erro é 422, não 500)" do
    assert_not Variante.new(produto: produtos(:camiseta), nome: "X", estoque: -5).valid?
    assert_not Variante.new(produto: produtos(:camiseta), estoque: 1).valid?, "nome é obrigatório"
    assert_not Produto.new(nome: "X", preco: 10, modo_venda: "sob_demanda", quantidade_alvo: 0).valid?
  end

  test "a loja exige login também na policy, não só no Devise (defesa em profundidade)" do
    assert_not ProdutoPolicy.new(nil, Produto).index?, "RN-17: anônimo não lê a loja"
    assert ProdutoPolicy.new(users(:ana), Produto).index?
  end

  test "apagar o produto leva as variantes junto" do
    assert_difference "Variante.count", -2 do
      produtos(:camiseta).destroy!
    end
  end
end
