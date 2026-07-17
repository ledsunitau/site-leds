require "test_helper"

class ReservaTest < ActiveSupport::TestCase
  test "só reserva produto sob_demanda e ativo (regra na aplicação)" do
    # camiseta é modo estoque → não reservável
    r = Reserva.new(user: users(:diretor), produto: produtos(:camiseta), quantidade: 1)
    assert_not r.valid?
    assert r.errors[:produto].any?

    # caneca_antiga é indisponível
    r = Reserva.new(user: users(:diretor), produto: produtos(:caneca_antiga), quantidade: 1)
    assert_not r.valid?

    # moletom é sob_demanda ativo → ok
    assert Reserva.new(user: users(:diretor), produto: produtos(:moletom), quantidade: 1).valid?
  end

  test "variante tem de pertencer ao produto (integridade + 422, não 500)" do
    # camiseta_m é variante de camiseta, não de moletom
    r = Reserva.new(user: users(:diretor), produto: produtos(:moletom),
                    variante: variantes(:camiseta_m), quantidade: 1)
    assert_not r.valid?
    assert r.errors[:variante].any?
  end

  test "uma reserva ativa por (usuário, produto, variante)" do
    # ana já tem ana_moletom (moletom + moletom_unico, ativa)
    dup = Reserva.new(user: users(:ana), produto: produtos(:moletom),
                      variante: variantes(:moletom_unico), quantidade: 1)
    assert_not dup.valid?
    assert dup.errors[:base].any?

    # mas se a anterior não está mais ativa, pode reservar de novo
    reservas(:ana_moletom).cancelar!
    assert Reserva.new(user: users(:ana), produto: produtos(:moletom),
                       variante: variantes(:moletom_unico), quantidade: 1).valid?
  end

  test "cancelar! vira 'cancelada' sem apagar; recancelar é 422" do
    reserva = reservas(:ana_moletom)

    assert_no_difference "Reserva.count", "cancelável é soft (RN-10)" do
      reserva.cancelar!
    end
    assert reserva.cancelada?

    assert_raises(ActiveRecord::RecordInvalid) { reserva.cancelar! }
  end

  test "reserva convertida (paga) não pode ser cancelada" do
    assert_raises(ActiveRecord::RecordInvalid) { reservas(:membro_convertida).cancelar! }
    assert reservas(:membro_convertida).reload.convertida?
  end

  test "quantidade tem de ser positiva" do
    assert_not Reserva.new(user: users(:diretor), produto: produtos(:moletom), quantidade: 0).valid?
  end
end
