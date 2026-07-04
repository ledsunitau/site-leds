# Seeds idempotentes (rodar quantas vezes quiser: bin/rails db:seed).
# Tudo numa transação: ou semeia inteiro, ou nada (sem estado pela metade).

ActiveRecord::Base.transaction do
  # --- Dados institucionais (todos os ambientes) ---
  diretorias = [
    "Diretoria de Mídias",
    "Diretoria Científica",
    "Diretoria de Extensão",
    "Tesouraria"
  ].index_with { |nome| Diretoria.find_or_create_by!(nome: nome) }

  # Só cria gestão se não existir NENHUMA (keyed no ano atual, re-rodar em
  # anos seguintes NÃO pode criar uma segunda gestão sobreposta).
  gestao = Gestao.order(:ano_inicio).last ||
           Gestao.create!(ano_inicio: Date.current.year - 1, ano_fim: Date.current.year + 1)

  # --- Fundadores placeholder (SÓ dev/test) ---
  # Senha fixa e pública no repo: jamais pode existir em produção; os dados
  # reais entram pela tela de admin (RF-ADM-03).
  if Rails.env.local?
    senha_dev = "leds-mudar-123"

    fundadores = [
      { nome: "Fundadora Presidente", email: "presidente@leds.dev", role: "presidencia",
        cargo: "presidente", diretoria: nil },
      { nome: "Fundador Vice", email: "vice@leds.dev", role: "presidencia",
        cargo: "vice", diretoria: nil },
      { nome: "Fundadora Mídias", email: "midias@leds.dev", role: "diretoria",
        cargo: "diretor", diretoria: "Diretoria de Mídias" },
      { nome: "Fundador Científica", email: "cientifica@leds.dev", role: "diretoria",
        cargo: "diretor", diretoria: "Diretoria Científica" },
      { nome: "Fundadora Extensão", email: "extensao@leds.dev", role: "diretoria",
        cargo: "diretor", diretoria: "Diretoria de Extensão" },
      { nome: "Fundador Tesouraria", email: "tesouraria@leds.dev", role: "diretoria",
        cargo: "diretor", diretoria: "Tesouraria" }
    ]

    fundadores.each do |f|
      user = User.find_or_create_by!(email: f[:email]) do |u|
        u.name = f[:nome]
        u.role = f[:role]
        u.password = senha_dev
      end

      member = Member.find_or_create_by!(user: user) { |m| m.founder = true }

      Mandato.find_or_create_by!(member: member, gestao: gestao) do |m|
        m.cargo = f[:cargo]
        m.diretoria = f[:diretoria] && diretorias[f[:diretoria]]
      end
    end
  end

  puts "Seeds: #{Diretoria.count} diretorias, gestão #{gestao.ano_inicio}–#{gestao.ano_fim}, " \
       "#{Member.where(founder: true).count} fundadores (fundadores só em dev/test)."
end
