require "test_helper"

class AcaoTest < ActiveSupport::TestCase
  test "delegated type expõe helpers e o detalhe" do
    acao = acoes(:acao_site)
    assert acao.projeto?
    assert_equal projetos(:site_liga), acao.detalhe
  end

  test "um detalhe só pode ter uma ação (único no banco)" do
    duplicada = Acao.new(titulo: "Dup", detalhe: projetos(:site_liga))
    assert_raises(ActiveRecord::RecordNotUnique) { duplicada.save!(validate: false) }
  end

  test "status fora da lista é rejeitado" do
    acao = Acao.new(titulo: "X", detalhe: Projeto.new, status: "aprovadissima")
    assert_not acao.valid?
    assert acao.errors[:status].any?
  end

  test "thumbnail rejeita arquivo que não é imagem" do
    acao = acoes(:acao_site)
    acao.thumbnail.attach(io: StringIO.new("MZ"), filename: "x.exe",
                          content_type: "application/octet-stream")
    assert_not acao.valid?
    assert acao.errors[:thumbnail].any?
  end

  test "destruir a ação destrói o detalhe junto" do
    assert_difference [ "Acao.count", "Projeto.count" ], -1 do
      acoes(:acao_bot).destroy!
    end
  end

  test "edições são versionadas com autor (PaperTrail)" do
    acao = acoes(:acao_site)
    PaperTrail.request(whodunnit: users(:diretor).id.to_s) do
      acao.update!(titulo: "Site novo")
    end

    versao = acao.versions.last
    assert_equal "update", versao.event
    assert_equal users(:diretor).id.to_s, versao.whodunnit
    assert_equal [ "Site institucional da LEDS", "Site novo" ],
                 versao.object_changes["titulo"]
  end
end
