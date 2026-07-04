require "test_helper"

class MemberTest < ActiveSupport::TestCase
  test "um perfil de membro por usuário" do
    duplicado = Member.new(user: users(:presidente_user))
    assert_not duplicado.valid?
    assert duplicado.errors.of_kind?(:user_id, :taken)
  end

  test "padrinho não pode ser o próprio membro (app e banco)" do
    member = members(:membro_comum)
    member.padrinho = member
    assert_not member.valid?

    assert_raises(ActiveRecord::StatementInvalid) do
      member.update_column(:padrinho_id, member.id)
    end
  end

  test "mandato_vigente usa o resolver único de gestão" do
    assert_equal mandatos(:diretor_vigente), members(:diretor_cientifica).mandato_vigente
  end

  test "foto institucional também é validada (tipo e tamanho)" do
    member = members(:membro_comum)
    member.foto.attach(io: StringIO.new("MZ..."), filename: "virus.exe",
                       content_type: "application/octet-stream")
    assert_not member.valid?
    assert member.errors[:foto].any?
  end

  test "foto_para_card usa a foto institucional e cai para a foto do usuário" do
    member = members(:membro_comum)
    assert_not member.foto_para_card.attached?

    member.user.foto.attach(io: StringIO.new("png"), filename: "perfil.png", content_type: "image/png")
    assert member.foto_para_card.attached?

    member.foto.attach(io: StringIO.new("png"), filename: "oficial.png", content_type: "image/png")
    assert_equal member.foto, member.reload.foto_para_card
  end
end
