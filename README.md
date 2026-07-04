# Sistema LEDS

Portal institucional e comunitário da Liga Acadêmica de Estrutura de Dados e Soluções.

- **Stack:** Ruby on Rails 8.1 (monólito modular) · PostgreSQL 17 · Solid Queue/Cache/Cable (sem Redis) · Hotwire
- **Docs autoritativas:** `LEDS_schema.sql` (DDL), `LEDS_Modelagem_de_Dados.md` e o PDF de Requisitos & Arquitetura v1.1 (fora deste repo)

## Desenvolvimento (Docker — não precisa de Ruby na máquina)

```bash
docker compose up
```

Sobe o PostgreSQL e o app em <http://localhost:3000>. Na primeira execução o
`db:prepare` cria os bancos e carrega `db/structure.sql` automaticamente.

Comandos úteis (sempre dentro do container):

```bash
docker compose run --rm web bin/rails test          # testes
docker compose run --rm web bin/rails db:prepare    # criar/migrar banco
docker compose run --rm web bin/rails console       # console
docker compose run --rm web bundle install          # após mudar o Gemfile
docker compose run --rm web bin/rubocop             # lint
```

> O schema usa `schema_format = :sql` (citext, CHECKs e triggers vivem em
> `db/structure.sql`) — por isso os comandos de banco precisam de `psql`,
> que já está instalado nas imagens. Rodar Rails fora do Docker exige
> Ruby 3.4 + PostgreSQL client instalados por conta própria.

## CI

GitHub Actions (`.github/workflows/ci.yml`): rubocop, brakeman, bundler-audit,
importmap audit e testes contra um Postgres 17 de verdade.

## Deploy

Kamal 2 em VPS único (`config/deploy.yml`) — configuração finalizada na fase
de deploy (branch `feature/deploy-producao`).
