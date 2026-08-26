require "net/http"

# Sincronização de cargos com o Discord (RF-EMB). Dois fluxos:
#
#   plano / aplicar!      — painel: os CARGOS do servidor espelham o que o site
#                           marcou com discord_sincronizar (cria, atualiza, apaga)
#   sincronizar_membro!   — perfil: os cargos DE UMA PESSOA batem com os emblemas
#                           que ela tem no site
#
# PORO, como Checkout e Frete. Inclui só DiscordRest (o REST puro) — a política
# de retry é de ActiveJob e não cabe aqui: quem clica está esperando resposta,
# então a falha vira mensagem na tela, não uma fila de tentativas.
#
# NADA acontece sem DISCORD_BOT_TOKEN e DISCORD_GUILD_ID. `configurado?` é o
# guard que as telas consultam antes de oferecer o botão.
class DiscordSync
  include DiscordRest

  # Modelos que podem virar cargo, e como cada um se descreve no servidor.
  # Lista fechada: cargo novo no site é uma linha aqui.
  FONTES = [
    { classe: "Emblema", nome: ->(e) { e.nome }, cor: ->(e) { e.cor } },
    { classe: "EmblemaNivel", nome: ->(n) { "#{n.emblema.nome} #{n.nome}" }, cor: ->(n) { n.cor } },
    { classe: "Elo", nome: ->(e) { e.nome }, cor: ->(e) { e.cor } }
  ].freeze

  class NaoConfigurado < StandardError; end

  Alvo = Struct.new(:registro, :nome, :cor, :role_id, keyword_init: true)

  def self.configurado? = ENV["DISCORD_BOT_TOKEN"].present? && ENV["DISCORD_GUILD_ID"].present?

  def self.plano = new.plano
  def self.aplicar!(apagar: false) = new.aplicar!(apagar: apagar)
  def self.sincronizar_membro!(user) = new.sincronizar_membro!(user)

  # ----------------------------------------------------------------- Painel

  # O diff entre o que o site quer e o que existe no servidor. Só LÊ — a tela
  # mostra antes de qualquer escrita, porque apagar cargo é irreversível.
  def plano
    exigir_configuracao!
    existentes = cargos_do_servidor.index_by { |c| c["id"] }
    alvos = alvos_marcados

    criar = alvos.reject { |a| a.role_id && existentes.key?(a.role_id) }
    atualizar = alvos.select do |a|
      atual = existentes[a.role_id]
      atual && (atual["name"] != a.nome || atual["color"] != cor_inteira(a.cor))
    end

    # órfão = cargo que NÓS criamos e que nenhum item marcado reivindica mais.
    # Cargo do servidor fora de discord_cargos jamais entra aqui.
    reivindicados = alvos.filter_map(&:role_id).to_set
    apagar = DiscordCargo.where.not(role_id: reivindicados.to_a).to_a

    { criar: criar, atualizar: atualizar, apagar: apagar }
  end

  def aplicar!(apagar: false)
    p = plano
    p[:criar].each { |alvo| criar_cargo(alvo) }
    p[:atualizar].each { |alvo| atualizar_cargo(alvo) }
    p[:apagar].each { |cargo| apagar_cargo(cargo) } if apagar

    { criados: p[:criar].size, atualizados: p[:atualizar].size,
      apagados: apagar ? p[:apagar].size : 0 }
  end

  # ----------------------------------------------------------------- Membro

  # Cross-check dos cargos de uma pessoa. Opera SÓ sobre os ids em
  # discord_cargos: um cargo de moderação nunca é removido por engano, mesmo
  # que a pessoa o tenha e o site não saiba dele.
  def sincronizar_membro!(user)
    exigir_configuracao!
    uid = user.discord_uid
    raise NaoConfigurado, "conta do Discord não vinculada" if uid.blank?

    nossos = DiscordCargo.ids
    atuais = cargos_do_membro(uid).to_set & nossos
    devidos = cargos_devidos(user).to_set & nossos

    adicionar = devidos - atuais
    remover = atuais - devidos
    adicionar.each { |role_id| cargo_do_membro(uid, role_id, Net::HTTP::Put) }
    remover.each { |role_id| cargo_do_membro(uid, role_id, Net::HTTP::Delete) }

    { adicionados: adicionar.size, removidos: remover.size }
  end

  # Os cargos que a pessoa DEVERIA ter: dos emblemas que possui, do rank
  # alcançado em cada um e do elo atual.
  def cargos_devidos(user)
    vinculos = EmblemaUsuario.where(user: user).includes(:emblema, :nivel)
    ids = vinculos.flat_map { |v| [ v.emblema.discord_role_id, v.nivel&.discord_role_id ] }
    (ids + [ user.elo&.discord_role_id ]).compact
  end

  private

  def exigir_configuracao!
    return if self.class.configurado?

    raise NaoConfigurado, "DISCORD_BOT_TOKEN e DISCORD_GUILD_ID precisam estar configurados"
  end

  def token = ENV["DISCORD_BOT_TOKEN"]
  def guild = ENV["DISCORD_GUILD_ID"]
  def guild_url = "#{API}/guilds/#{guild}"

  # Todo item marcado para espelhar, de todas as fontes.
  def alvos_marcados
    FONTES.flat_map do |fonte|
      escopo = fonte[:classe].constantize.where(discord_sincronizar: true)
      escopo = escopo.includes(:emblema) if fonte[:classe] == "EmblemaNivel"
      escopo.map do |registro|
        Alvo.new(registro: registro, nome: fonte[:nome].call(registro),
                 cor: fonte[:cor].call(registro), role_id: registro.discord_role_id)
      end
    end
  end

  # "#00C55B" -> 12893 (o Discord guarda cor como inteiro decimal)
  def cor_inteira(hex) = hex.to_s.delete("#").to_i(16)

  def cargos_do_servidor
    json_discord(chamar_discord(Net::HTTP::Get, "#{guild_url}/roles", auth_discord(token))) || []
  end

  def cargos_do_membro(uid)
    membro = json_discord(chamar_discord(Net::HTTP::Get, "#{guild_url}/members/#{uid}",
                                         auth_discord(token)))
    membro&.fetch("roles", []) || []
  end

  def cargo_do_membro(uid, role_id, verbo)
    chamar_discord(verbo, "#{guild_url}/members/#{uid}/roles/#{role_id}", auth_discord(token))
  end

  def criar_cargo(alvo)
    resposta = chamar_discord(Net::HTTP::Post, "#{guild_url}/roles", auth_discord(token),
                              { name: alvo.nome, color: cor_inteira(alvo.cor), mentionable: true })
    role_id = json_discord(resposta)&.dig("id")
    return if role_id.blank?

    # o id volta para o registro: é o que o DiscordCargoJob usa nos eventos
    alvo.registro.update_column(:discord_role_id, role_id)
    DiscordCargo.registrar!(role_id, nome: alvo.nome, cor: alvo.cor)
  end

  def atualizar_cargo(alvo)
    chamar_discord(Net::HTTP::Patch, "#{guild_url}/roles/#{alvo.role_id}", auth_discord(token),
                   { name: alvo.nome, color: cor_inteira(alvo.cor) })
    DiscordCargo.registrar!(alvo.role_id, nome: alvo.nome, cor: alvo.cor)
  end

  # 404 = já não existe lá (apagado à mão). O registro sai do mesmo jeito —
  # senão o órfão apareceria no diff para sempre.
  def apagar_cargo(cargo)
    chamar_discord(Net::HTTP::Delete, "#{guild_url}/roles/#{cargo.role_id}", auth_discord(token))
    cargo.destroy!
  rescue DiscordRest::ErroPermanente
    cargo.destroy!
  end
end
