require "test_helper"

class MembersControllerTest < ActionDispatch::IntegrationTest
  test "index é público e lista só quem tem mandato na gestão vigente" do
    get members_path

    body = response.parsed_body
    ids = body["members"].map { |m| m["id"] }
    assert_includes ids, members(:pres).id
    assert_includes ids, members(:membro_comum).id
    assert_equal 5, ids.size # diretor_antiga não duplica o diretor
  end

  test "filtra por cargo" do
    get members_path(cargo: "diretor")

    body = response.parsed_body["members"]
    assert_equal [ members(:diretor_cientifica).id ], body.map { |m| m["id"] }
    assert_equal "Diretoria Científica", body.first["diretoria"]
    assert body.first["destaque"]
  end

  test "filtro com hash/array na query string não derruba o endpoint" do
    get members_path(cargo: { x: "y" })
    assert_response :success

    get members_path(diretoria_id: [ "1", "2" ])
    assert_response :success
    assert_equal 5, response.parsed_body["members"].size # filtro não-escalar é ignorado
  end

  test "filtra por diretoria" do
    get members_path(diretoria_id: diretorias(:cientifica).id)

    ids = response.parsed_body["members"].map { |m| m["id"] }
    assert_equal [ members(:diretor_cientifica).id, members(:membro_comum).id ].sort, ids.sort
  end

  test "show traz o card com tag de fundador e discord" do
    get member_path(members(:pres))

    body = response.parsed_body
    assert body["founder"]
    assert_equal "presidente", body["cargo"]
    assert_equal "Paula Presidente", body["name"]
  end

  test "grafo liga vice/diretor/orientador ao presidente e membro ao diretor (RN-06)" do
    get grafo_members_path

    body = response.parsed_body
    assert_equal 5, body["nodes"].size

    pres = members(:pres).id
    edges = body["edges"].map { |e| [ e["from"], e["to"] ] }
    assert_includes edges, [ members(:vice).id, pres ]
    assert_includes edges, [ members(:diretor_cientifica).id, pres ]
    assert_includes edges, [ members(:orientador).id, pres ]
    assert_includes edges, [ members(:membro_comum).id, members(:diretor_cientifica).id ]
    assert_equal 4, edges.size
  end

  test "geneograma traz gestões em ordem, padrinhos e fundadores" do
    get geneograma_members_path

    body = response.parsed_body
    assert_equal [ gestoes(:antiga).ano_inicio, gestoes(:vigente).ano_inicio ],
                 body["gestoes"].map { |g| g["ano_inicio"] }

    antiga = body["gestoes"].first
    assert_equal [ members(:diretor_cientifica).id ], antiga["mandatos"].map { |m| m["member_id"] }

    padrinho_ids = body["padrinho_edges"].map { |e| [ e["member_id"], e["padrinho_id"] ] }
    assert_includes padrinho_ids, [ members(:membro_comum).id, members(:diretor_cientifica).id ]

    founder_ids = body["founders"].map { |f| f["member_id"] }
    assert_equal [ members(:pres).id, members(:vice).id ].sort, founder_ids.sort
  end
end
