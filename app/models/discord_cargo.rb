# Registro dos cargos que o SITE criou no servidor do Discord.
#
# Existe por um motivo só: segurança na exclusão. Quando o gestor apaga um
# emblema, o discord_role_id vai junto — sem este registro não haveria como
# saber que aquele cargo lá no servidor tinha sido nosso, e "apagar o órfão"
# viraria apagar cargo que não é da gente (moderação, bots, cargos manuais).
#
# A regra que sai daqui: DiscordSync só apaga role_id que está nesta tabela.
class DiscordCargo < ApplicationRecord
  validates :role_id, presence: true, uniqueness: true

  # Todo cargo que gerenciamos, para comparar contra o que o servidor devolve.
  def self.ids = pluck(:role_id).to_set

  # Passa a gerenciar (ou atualiza o que sabemos sobre) um cargo.
  def self.registrar!(role_id, nome:, cor:)
    cargo = find_or_initialize_by(role_id: role_id.to_s)
    cargo.update!(nome: nome, cor: cor)
    cargo
  end
end
