require "test_helper"

# RF-NOV-04: quem escreve o quê.
#
# Membro da liga (membro/diretoria/presidência) escreve os dois tipos. Fora da
# liga o papel diz qual: escritor → blog, jornalista → notícia. Esta é a ÚNICA
# fonte da regra — a tela de escrita, o select de tipo e o botão em /novidades
# derivam daqui, então uma quebra aqui vaza para os três.
class PostPolicyTest < ActiveSupport::TestCase
  def pode_escrever?(usuario, tipo)
    PostPolicy.new(usuario, Post.new(tipo: tipo)).create?
  end

  test "escritor escreve blog e NÃO escreve notícia" do
    escritor = users(:escritor_user)

    assert pode_escrever?(escritor, "blog")
    assert_not pode_escrever?(escritor, "noticia")
  end

  test "jornalista escreve notícia e NÃO escreve blog" do
    jornalista = users(:jornalista_user)

    assert pode_escrever?(jornalista, "noticia")
    assert_not pode_escrever?(jornalista, "blog")
  end

  test "a liga inteira escreve os dois tipos" do
    [ users(:membro_user), users(:diretor), users(:presidente_user) ].each do |usuario|
      assert pode_escrever?(usuario, "blog"),    "#{usuario.role} devia escrever blog"
      assert pode_escrever?(usuario, "noticia"), "#{usuario.role} devia escrever notícia"
    end
  end

  test "comunidade, parceiro e anônimo não escrevem nada" do
    [ users(:ana), users(:parceiro_user), nil ].each do |usuario|
      Post::TIPOS.each do |tipo|
        assert_not pode_escrever?(usuario, tipo),
                   "#{usuario&.role || 'anônimo'} não pode escrever #{tipo}"
      end
    end
  end

  # 403 aqui mascararia o erro real: tipo inválido é 422 da validação do enum.
  test "tipo ausente ou inválido libera para quem escreve QUALQUER tipo" do
    [ nil, "cronica" ].each do |tipo|
      assert pode_escrever?(users(:escritor_user), tipo)
      assert pode_escrever?(users(:jornalista_user), tipo)
      assert_not pode_escrever?(users(:ana), tipo)
    end
  end

  # RN-02: quem escreve não se aprova. Escritor e jornalista NÃO são gestão.
  test "escritor e jornalista não aprovam nem rejeitam" do
    post = posts(:blog_em_aprovacao)

    [ users(:escritor_user), users(:jornalista_user) ].each do |usuario|
      assert_not PostPolicy.new(usuario, post).aprovar?
      assert_not PostPolicy.new(usuario, post).rejeitar?
    end

    assert PostPolicy.new(users(:diretor), post).aprovar?
  end
end
