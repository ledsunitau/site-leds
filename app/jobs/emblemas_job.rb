# RF-EMB: varredura periódica. Concede os emblemas de meta a quem bateu o
# número, acompanha o rank dos escalonáveis de métrica e reacerta pontos/elo.
#
# Por que varredura e não hook em cada model: os sete critérios vivem em Post,
# Ideia, Acao, Comentario, Avaliacao, Pedido e na data de cadastro — um
# after_commit em cada um seria sete pontos para manter em sincronia, e o de
# "dias de conta" não teria evento nenhum para pendurar. Um lugar só.
#
# O recálculo de elo entra aqui porque os pontos mudam por fora de qualquer
# concessão: a gestão edita o peso de um rank ou cria um elo novo e a base
# inteira muda de posição. O painel enfileira este mesmo job depois dessas
# edições, para não esperar a hora cheia. `recalcular_elo!` sai cedo quando nada
# mudou, então a passagem por quem não mexeu é barata.
#
# ponytail: uma consulta por critério por usuário. Ok na escala atual (centenas
# de contas); se crescer, agregar por critério numa consulta só. As telas de
# emblema do próprio usuário chamam Emblema.avaliar! direto, então a conquista
# não espera a hora cheia.
class EmblemasJob < ApplicationJob
  queue_as :default

  def perform
    return unless Setting.ativo?("emblemas_ativos")

    avaliar = Emblema.ativos.com_meta.any?
    User.find_each do |user|
      Emblema.avaliar!(user) if avaliar
      user.recalcular_elo!
    end
  end
end
