require "test_helper"

class ArtigoTest < ActiveSupport::TestCase
  test "artigo precisa de 1 a 3 temas (RN-18, mínimo na aplicação)" do
    sem_tema = Artigo.new(situacao: "em_desenvolvimento")
    assert_not sem_tema.valid?
    assert sem_tema.errors[:temas].any?

    com_tema = Artigo.new(situacao: "em_desenvolvimento",
                          tema_ids: [ temas(:estruturas).id ])
    assert com_tema.valid?

    demais = Artigo.new(situacao: "em_desenvolvimento",
                        tema_ids: [ temas(:estruturas), temas(:ia), temas(:web), temas(:educacao) ].map(&:id))
    assert_not demais.valid?
  end

  test "máximo de 3 temas é garantido no BANCO (trigger)" do
    artigo = artigos(:artigo_ed) # já tem 1 tema
    ArtigoTema.create!(artigo: artigo, tema: temas(:ia))
    ArtigoTema.create!(artigo: artigo, tema: temas(:web))

    erro = assert_raises(ActiveRecord::StatementInvalid) do
      ArtigoTema.create!(artigo: artigo, tema: temas(:educacao))
    end
    assert_match(/no máximo 3 temas/, erro.message)
  end

  test "finalizado exige data de finalização (app e banco)" do
    artigo = artigos(:artigo_ed)
    artigo.data_finalizacao = nil
    assert_not artigo.valid?

    assert_raises(ActiveRecord::StatementInvalid) do
      artigo.update_column(:data_finalizacao, nil)
    end
  end

  test "autores vêm ordenados pela ordem de autoria" do
    assert_equal [ "Dario Diretor", "Coautora Externa" ],
                 artigos(:artigo_ed).autores.map(&:nome)
  end

  test "autor externo não tem member; membro tem (mesma tabela)" do
    assert_nil autores(:autor_externo).member
    assert_equal members(:diretor_cientifica), autores(:autora_membro).member
  end

  test "apresentação é única por artigo+congresso+ano" do
    dup = Apresentacao.new(artigo: artigos(:artigo_ed),
                           congresso: congressos(:cicted), ano: 2025)
    assert_not dup.valid?
  end
end
