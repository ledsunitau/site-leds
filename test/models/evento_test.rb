require "test_helper"

class EventoTest < ActiveSupport::TestCase
  test "estado é derivado das datas (vai acontecer / acontecendo / já aconteceu)" do
    travel_to Time.zone.local(2026, 7, 10, 12) do
      futuro = Evento.new(data_inicio: 2.days.from_now)
      assert_equal "vai_acontecer", futuro.estado

      rolando = Evento.new(data_inicio: 1.hour.ago, data_fim: 2.hours.from_now)
      assert_equal "acontecendo", rolando.estado

      passado = Evento.new(data_inicio: 2.days.ago, data_fim: 1.day.ago)
      assert_equal "ja_aconteceu", passado.estado
    end
  end

  test "sem data_fim, o evento acontece até o fim do dia de início" do
    travel_to Time.zone.local(2026, 7, 10, 22) do
      hoje = Evento.new(data_inicio: 6.hours.ago)
      assert_equal "acontecendo", hoje.estado

      ontem = Evento.new(data_inicio: 30.hours.ago)
      assert_equal "ja_aconteceu", ontem.estado
    end
  end

  test "data_fim antes do início é rejeitada (app e banco)" do
    evento = eventos(:hackathon)
    evento.data_fim = evento.data_inicio - 1.hour
    assert_not evento.valid?

    assert_raises(ActiveRecord::StatementInvalid) do
      evento.update_column(:data_fim, evento.data_inicio - 1.hour)
    end
  end

  test "papel de participação é único por evento+membro" do
    dup = EventoMembro.new(evento: eventos(:hackathon),
                           member: members(:diretor_cientifica), papel: "organizador")
    assert_not dup.valid?
  end
end
