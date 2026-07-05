require "test_helper"

# Testes dos dois tipos delegados novos (Evento e Artigo) — os de Projeto
# vivem em acoes_controller_test.rb.
class AcoesEventosArtigosTest < ActionDispatch::IntegrationTest
  test "filtro por tipo retorna eventos e artigos" do
    get acoes_path(tipo: "Evento")
    assert_equal [ acoes(:acao_hackathon).id ], response.parsed_body["acoes"].map { |a| a["id"] }

    get acoes_path(tipo: "Artigo")
    assert_equal [ acoes(:acao_artigo).id ], response.parsed_body["acoes"].map { |a| a["id"] }
  end

  test "card de artigo já traz os ícones/nomes dos temas" do
    get acoes_path(tipo: "Artigo")

    temas = response.parsed_body["acoes"].first["detalhe"]["temas"]
    assert_equal [ "Estruturas de Dados" ], temas.map { |t| t["nome"] }
  end

  test "show de evento traz organizadores, participantes, convidados e agenda" do
    get acao_path(acoes(:acao_hackathon))

    detalhe = response.parsed_body["detalhe"]
    assert_equal "vai_acontecer", detalhe["estado"]
    assert_equal [ members(:diretor_cientifica).id ], detalhe["organizadores"].map { |o| o["member_id"] }
    assert_equal [ members(:membro_comum).id ], detalhe["participantes"].map { |p| p["member_id"] }

    convidado = detalhe["convidados"].first
    assert_equal "Dra. Convidada", convidado["nome"]
    assert_equal [ { "rede" => "linkedin", "url" => "https://linkedin.com/in/convidada" } ],
                 convidado["links"]

    assert_match(/calendar\.google\.com/, detalhe["google_calendar_url"])
    assert_equal ics_acao_path(acoes(:acao_hackathon)), detalhe["ics_url"]
  end

  test "show de artigo traz abstract, autores ordenados, temas e congressos" do
    get acao_path(acoes(:acao_artigo))

    detalhe = response.parsed_body["detalhe"]
    assert_equal "finalizado", detalhe["situacao"]
    assert_equal [ 1, 2 ], detalhe["autores"].map { |a| a["ordem"] }
    assert_nil detalhe["autores"].last["member_id"] # coautora externa
    assert_equal [ { "congresso" => "CICTED", "ano" => 2025 } ], detalhe["apresentacoes"]
  end

  test "membro cria ação-evento completa" do
    sign_in users(:membro_user)

    assert_difference [ "Acao.count", "Evento.count", "Convidado.count" ], 1 do
      post acoes_path, params: {
        acao: {
          titulo: "Semana da Computação",
          status: "publicada",
          evento: { local: "Campus", data_inicio: 10.days.from_now.iso8601 },
          evento_membros: [ { member_id: members(:membro_comum).id, papel: "organizador" } ],
          convidados: [ { nome: "Prof. Externo", links: [ { rede: "site", url: "https://x.dev" } ] } ]
        }
      }
    end

    assert_response :created
    detalhe = response.parsed_body["detalhe"]
    assert_equal "vai_acontecer", detalhe["estado"]
    assert_equal 1, detalhe["organizadores"].size
  end

  test "membro cria ação-artigo com temas, autores e apresentação" do
    sign_in users(:membro_user)

    assert_difference [ "Acao.count", "Artigo.count" ], 1 do
      post acoes_path, params: {
        acao: {
          titulo: "IA no ensino médio",
          status: "publicada",
          artigo: { abstract: "Resumo.", situacao: "em_desenvolvimento" },
          tema_ids: [ temas(:ia).id, temas(:educacao).id ],
          autores: [
            { member_id: members(:membro_comum).id, nome: "Marcos Membro", ordem: 1 },
            { nome: "Externa", lattes_url: "http://lattes.cnpq.br/7", ordem: 2 }
          ],
          apresentacoes: [ { congresso_id: congressos(:cicted).id, ano: 2026 } ]
        }
      }
    end

    assert_response :created
    detalhe = response.parsed_body["detalhe"]
    assert_equal 2, detalhe["temas"].size
    assert_equal 2, detalhe["autores"].size
  end

  test "artigo sem temas é 422; com 4 temas também" do
    sign_in users(:membro_user)

    post acoes_path, params: {
      acao: { titulo: "Sem tema", artigo: { situacao: "em_desenvolvimento" } }
    }
    assert_response :unprocessable_entity
    assert_match(/1 a 3 temas/, response.parsed_body["errors"].first)

    patch acao_path(acoes(:acao_artigo)), params: {
      acao: { tema_ids: [ temas(:estruturas), temas(:ia), temas(:web), temas(:educacao) ].map(&:id) }
    }
    assert_response :unprocessable_entity
  end

  test "update de evento substitui participações por inteiro" do
    sign_in users(:membro_user)

    patch acao_path(acoes(:acao_hackathon)), params: {
      acao: { evento_membros: [ { member_id: members(:vice).id, papel: "participante" } ] }
    }

    assert_response :success
    evento = eventos(:hackathon).reload
    assert_equal [ [ members(:vice).id, "participante" ] ],
                 evento.evento_membros.pluck(:member_id, :papel)
  end

  test "calendário lista eventos publicados no intervalo" do
    get calendario_acoes_path(de: Date.current.iso8601, ate: (Date.current + 60.days).iso8601)

    eventos = response.parsed_body["eventos"]
    assert_equal [ acoes(:acao_hackathon).id ], eventos.map { |e| e["acao_id"] }
    assert_equal "vai_acontecer", eventos.first["estado"]
    assert_match(/calendar\.google\.com/, eventos.first["google_calendar_url"])
  end

  test "ics devolve text/calendar com DTSTART e escapa vírgulas" do
    get ics_acao_path(acoes(:acao_hackathon))

    assert_response :success
    assert_match "text/calendar", response.content_type
    assert_includes response.body, "BEGIN:VEVENT"
    assert_includes response.body, "DTSTART:"
    assert_includes response.body, "SUMMARY:Hackathon LEDS"
    assert response.body.include?("\r\n"), "linhas do ics devem terminar em CRLF"
  end

  test "ics de ação que não é evento é 404" do
    get ics_acao_path(acoes(:acao_site))
    assert_response :not_found
  end

  test "tema_ids com strings vazias não zera os temas (RN-18)" do
    sign_in users(:membro_user)

    patch acao_path(acoes(:acao_artigo)), params: { acao: { tema_ids: [ "" ] } }

    assert_response :unprocessable_entity
    assert_equal 1, artigos(:artigo_ed).reload.temas.count
  end

  test "troca de temas gera versões de auditoria (junção não usa delete_all)" do
    sign_in users(:membro_user)

    assert_difference -> { PaperTrail::Version.where(item_type: "ArtigoTema").count }, 2 do
      patch acao_path(acoes(:acao_artigo)), params: { acao: { tema_ids: [ temas(:ia).id ] } }
    end

    eventos = PaperTrail::Version.where(item_type: "ArtigoTema").order(:id).last(2).map(&:event)
    assert_equal %w[destroy create], eventos
  end

  test "POST sem a chave acao é 400, não 500" do
    sign_in users(:membro_user)
    post acoes_path, params: { titulo: "sem envelope" }
    assert_response :bad_request
  end

  test "create exige exatamente um tipo de detalhe" do
    sign_in users(:membro_user)
    post acoes_path, params: { acao: { titulo: "Sem tipo" } }

    assert_response :unprocessable_entity
    assert_match(/projeto.*evento.*artigo/i, response.parsed_body["errors"].first)
  end
end
