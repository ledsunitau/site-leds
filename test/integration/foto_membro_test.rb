require "test_helper"

# A foto do card em /membros tem que sair na variante GRANDE.
#
# Bug de produção: `.membro-foto` é um box de 300×360 (240 de altura e largura
# cheia abaixo de 720px) e recebia a variante :avatar, de 96px. Em tela HiDPI o
# navegador ampliava 7,5× e a foto ficava pixelada.
#
# O teste de model (FotoVariantesTest) crava o TAMANHO das variantes. Este crava
# o CALL SITE: que a página pede a variante certa. São regressões diferentes —
# dá para consertar o tamanho e alguém reverter a chamada, ou o contrário.
class FotoMembroTest < ActionDispatch::IntegrationTest
  # A URL de uma variante é
  #   /rails/active_storage/representations/redirect/<blob>/<chave>/<arquivo>
  # e <chave> é a transformação assinada. Decodificar é o único jeito de afirmar
  # QUAL variante a página pediu — o nome (:retrato) não aparece na URL.
  def medidas_da_url(url)
    chave = url[%r{/representations/(?:redirect/)?[^/]+/([^/]+)/}, 1]
    assert chave, "não é URL de variante: #{url}"

    t = ActiveStorage::Variation.decode(chave).transformations
    # :avatar usa _fill (display sempre quadrado), :retrato usa _limit (a
    # proporção do box inverte por breakpoint) — ver User#foto.
    t[:resize_to_fill] || t[:resize_to_limit]
  end

  # Bytes falsos de propósito, como os outros testes de anexo do projeto: o
  # `variable?` do Active Storage decide pelo content_type declarado, e aqui só
  # interessa a URL — nada é processado pelo libvips.
  def membro_com_foto
    members(:pres).tap do |m|
      m.foto.attach(io: StringIO.new("x"), filename: "foto.png", content_type: "image/png")
    end
  end

  test "o card de membro pede a variante :retrato, não a :avatar" do
    membro_com_foto

    get members_path, headers: { "Accept" => "text/html" }
    assert_response :success

    urls = css_select("div.membro-foto").filter_map { |div| div["style"][/url\('([^']+)'\)/, 1] }
    assert urls.any?, "a página precisa ter card de membro para este teste valer"

    variantes = urls.select { |u| u.include?("/representations/") }
    assert variantes.any?,
           "nenhuma foto saiu como variante — só placeholder ou blob original"

    variantes.each do |url|
      assert_equal [ 720, 900 ], medidas_da_url(url),
                   "o box é 300×360; :avatar (192) seria ampliado 3× em HiDPI"
    end
  end

  # O contraponto: o avatar pequeno NÃO deve carregar a foto grande — seria
  # trocar um desperdício por outro.
  test "os participantes do card de ação seguem na variante pequena" do
    url = ApplicationController.helpers.foto_de_membro(membro_com_foto)

    assert_equal [ 192, 192 ], medidas_da_url(url)
  end
end
