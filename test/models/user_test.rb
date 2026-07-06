require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "email é único ignorando caixa (citext)" do
    duplicate = User.new(
      email: "ANA@EXAMPLE.COM", name: "Outra Ana", password: "senha-segura-123"
    )
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:email, :taken)
  end

  test "name é obrigatório" do
    user = User.new(email: "novo@example.com", password: "senha-segura-123")
    assert_not user.valid?
    assert user.errors.of_kind?(:name, :blank)
  end

  test "role padrão é comunidade e aceita só os papéis da matriz" do
    user = User.new(email: "novo@example.com", name: "Novo", password: "senha-segura-123")
    assert_equal "comunidade", user.role

    # validate: true — inválido é erro de validação (422), não ArgumentError
    user.role = "hacker"
    assert_not user.valid?
    assert user.errors.of_kind?(:role, :inclusion)
  end

  test "CHECK do banco rejeita role fora da lista" do
    user = users(:ana)
    assert_raises(ActiveRecord::StatementInvalid) do
      user.update_column(:role, "invalido")
    end
  end

  test "discord_username vem da identidade vinculada" do
    assert_equal "aninha", users(:ana).discord_username
    assert_nil users(:diretor).discord_username
  end

  test "destruir usuário destrói o membro via callbacks (purga anexos)" do
    assert_difference "Member.count", -1 do
      users(:membro_user).destroy!
    end
  end

  test "foto rejeita arquivo que não é imagem" do
    user = users(:ana)
    user.foto.attach(io: StringIO.new("MZ..."), filename: "virus.exe",
                     content_type: "application/octet-stream")
    assert_not user.valid?
    assert user.errors[:foto].any?
  end

  test "foto aceita imagem pequena" do
    user = users(:ana)
    user.foto.attach(io: StringIO.new("png-fake"), filename: "foto.png",
                     content_type: "image/png")
    assert user.valid?
  end
end
