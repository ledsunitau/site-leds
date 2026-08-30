# Sistema LEDS

Portal institucional e comunitário da **LEDS** — Liga Acadêmica de Estrutura de
Dados e Soluções, da Universidade de Taubaté (UNITAU), Taubaté/SP.

Um monólito Rails que resolve, num sistema só, o que a liga fazia espalhado em 
planilha, Instagram e Discord: portfólio de projetos, quadro de membros com histórico de gestões,
publicação com fila de aprovação, loja com pagamento e frete reais, e um sistema
de conquistas que sincroniza cargo no Discord.

> **Status:** em desenvolvimento ativo. O código está completo o suficiente para
> subir (Kamal + Cloudflare + R2 configurados em `config/deploy.yml`), mas ainda
> **não há instância pública** — faltam o VPS e o domínio. Não há URL de demo.

---

## Funcionalidades

<table>
<tr><th align="left">Domínio</th><th align="left">O que faz</th></tr>

<tr><td><b>Ações</b></td><td>
Portfólio da liga em três formas — <b>Projeto</b>, <b>Evento</b> e <b>Artigo</b> —
que compartilham o card e divergem no detalhe (stack de tecnologias,
local/data, temas e autores). Calendário de eventos e exportação <code>.ics</code>
para adicionar na agenda.
</td></tr>

<tr><td><b>Membros</b></td><td>
Fichas com foto, bio, skills e ações creditadas. Duas visualizações de grafo:
a <b>rede</b> da gestão vigente (quem trabalhou com quem) e o <b>genograma
acadêmico</b> (quem apadrinhou quem, ao longo das gestões).
</td></tr>

<tr><td><b>Novidades</b></td><td>
Notícias e blog com <b>dois modos de editor</b> — rico (Action Text/Trix) ou
Markdown —, <b>fila de aprovação</b> (rascunho → em aprovação →
publicado/rejeitado), histórico de versões navegável, comentários e denúncias
moderadas. Ao publicar, anuncia no Discord. A tela de escrita fica <b>fora do
painel</b>: escritor (blog) e jornalista (notícia) publicam sem nunca ter
acesso à gestão.
</td></tr>

<tr><td><b>Ideias</b></td><td>
Qualquer pessoa da comunidade propõe uma ideia; aprovada pela gestão, ela vira
uma Ação — e o autor fica registrado como idealizador.
</td></tr>

<tr><td><b>Loja</b></td><td>
Catálogo com variantes (tamanho/cor) e estoque, carrinho, <b>reservas</b> para
produção sob demanda, checkout, <b>Mercado Pago</b> (com validação HMAC do
webhook), cotação e rastreio pelo <b>Melhor Envio</b>, e avaliações de quem
comprou.
</td></tr>

<tr><td><b>Emblemas</b></td><td>
Gamificação com raridade <b>derivada</b>: nenhuma gestão escolhe se um emblema é
"lendário" — a faixa sai do percentual de contas que o possuem. Emblemas únicos
ou escalonáveis (bronze → elite), conquistados por meta, concessão, link
exclusivo ou compra. Quem ganha recebe o <b>cargo correspondente no Discord</b>,
automaticamente. Os pontos somam num <b>elo</b> com ranking do degrau mais alto.
</td></tr>

<tr><td><b>Parceiros</b></td><td>
Vitrine de parceiros, vínculo com as ações que apoiaram e formulário público de
proposta com triagem pela gestão.
</td></tr>

<tr><td><b>Gestão</b></td><td>
Painel HTML completo (<code>/painel</code>): fila unificada de aprovações,
moderação, catálogos, pedidos, pessoas e papéis, métricas, logs de erro,
auditoria e LGPD. Feature flags para ligar/desligar loja, ideias, comentários,
cadastro — e um <b>modo manutenção</b> que fecha o site para quem não é gestão.
</td></tr>

<tr><td><b>Notificações</b></td><td>
Um evento, N entregas: <b>e-mail</b>, <b>Web Push</b> (VAPID) e <b>DM no
Discord</b>, com preferências por categoria e canal.
</td></tr>

<tr><td><b>LGPD</b></td><td>
Banner de consentimento tri-estado, analytics que <b>só</b> coleta com opt-in
(revalidado no servidor, não só no cliente), e tela de eliminação de dados.
</td></tr>
</table>

---

## Decisões de arquitetura

**Monólito Rails, sem SPA.** Páginas renderizadas no servidor com Hotwire.
Turbo Frames trocam só o pedaço que muda (filtrar a grade de ações não recarrega
navbar nem folha de estilo), e Stimulus cuida do que é interação de tela. Sem
build step de JavaScript: `importmap` serve os módulos direto, e os controllers
Stimulus carregam **sob demanda**, quando o `data-controller` aparece no DOM.

**Sem Redis.** Cache, filas e WebSocket usam a *Solid Trifecta* do Rails 8
(`solid_cache`, `solid_queue`, `solid_cable`) sobre o próprio PostgreSQL.

**`schema_format = :sql`.** O schema usa `citext`, `CHECK` constraints e
triggers; `schema.rb` não representa nada disso. A verdade vive em
`db/structure.sql`, e regra de integridade fica no banco quando o banco sabe
expressá-la — não só na validação do model.

**Detalhe polimórfico em Ações.** `Acao` carrega o que os três tipos têm em
comum (título, thumbnail, status, autoria) e delega o resto para
`Projeto`/`Evento`/`Artigo`. Evita tanto três tabelas quase iguais quanto uma
tabela com metade das colunas sempre nula.

**Estado derivado, não coluna.** Raridade de emblema, elo do usuário, estado do
evento ("vai acontecer"/"acontecendo"/"já aconteceu") são calculados de onde a
verdade já está. Cada coluna a mais seria um segundo lugar para a mesma
informação — e um lugar para elas divergirem.

**Filtro e paginação no servidor.** As listagens públicas resolvem chips, busca
e página como parâmetros de URL, e respondem por Turbo Frame. O filtro
client-side que existia antes era instantâneo, mas mandava a tabela inteira para
o navegador e a busca só enxergava o que já estava na tela. De brinde, o filtro
virou URL compartilhável e o botão voltar passou a funcionar.

**Autorização por policy, auditoria por padrão.** Pundit em toda ação;
PaperTrail em tudo que a gestão altera, com o diff visível na tela de auditoria.

**Defesa em duas camadas.** `Rack::Attack` por rota na aplicação e rate limiting
por IP na borda do Cloudflare — documentados juntos em
[`docs/deploy.md`](docs/deploy.md).

---

## Stack

| Camada | Escolha |
|---|---|
| Runtime | Ruby 3.4.9 · Rails 8.1 |
| Banco | PostgreSQL 17 (`citext`, CHECKs, triggers) |
| Cache / Filas / Cable | Solid Cache · Solid Queue · Solid Cable (sem Redis) |
| Front-end | Hotwire (Turbo + Stimulus) · Importmap · Propshaft · CSS próprio |
| Auth | Devise · OmniAuth (Google, Discord) |
| Autorização | Pundit |
| Auditoria | PaperTrail |
| Notificações | Noticed (e-mail, Web Push/VAPID, DM no Discord) |
| Arquivos | Active Storage + Cloudflare R2 · variantes WebP via libvips |
| Pagamento / Frete | Mercado Pago · Melhor Envio |
| Deploy | Kamal 2 · Docker · Cloudflare |
| Qualidade | Minitest · RuboCop (omakase) · Brakeman · bundler-audit |

## Números

| | |
|---|---|
| Tabelas | 63 |
| Models · Controllers · Views | 57 · 90 · 124 |
| Policies · Jobs | 14 · 9 |
| Testes | **663** (2.517 asserções) |
| Ruby em `app/` | ~10.000 linhas |
| Idioma | pt-BR (interface e código) |

---

## Rodando localmente

Não precisa de Ruby, Node nem Postgres na máquina — só Docker.

```bash
git clone https://github.com/ledsunitau/site-leds.git
cd site-leds
docker compose up
```

Sobe o PostgreSQL e o app em <http://localhost:3000>. Na primeira execução o
`db:prepare` cria os bancos e carrega `db/structure.sql` automaticamente.

### Entrar

`bin/rails db:seed` popula um ambiente de demonstração — e é idempotente, então
rode quantas vezes quiser (inclusive para recuperar a senha de um usuário de
seed que você tenha trocado). Todos usam a senha **`leds-mudar-123`**:

| Conta | Papel |
|---|---|
| `presidente@leds.dev` | presidência (abre o `/painel`) |
| `midias@leds.dev` | diretoria |
| `escritor@leds.dev` | escritor — escreve **blog** em `/novidades`, sem `/painel` |
| `jornalista@leds.dev` | jornalista — escreve **notícia** em `/novidades`, sem `/painel` |
| `bruno@leds.dev` | comunidade |

Essas contas só existem em dev e teste — o seed as cria dentro de um
`if Rails.env.local?`, então produção nunca as vê.

### Integrações externas ficam DESLIGADAS localmente

`docker-compose.override.yml` (aplicado automaticamente pelo Compose) zera as
credenciais de Discord, Mercado Pago, Melhor Envio e OAuth no ambiente local.

Isso não é higiene, é contenção: com credenciais reais no `.env`, publicar uma
novidade no painel local **anunciaria no Discord de verdade** da liga, e clicar
em "Continuar com Google" levaria você para o callback de **produção** — saindo
do ambiente local sem aviso.

Consequências práticas no dev:

- Entre por **e-mail e senha**. Os botões de OAuth aparecem, mas dão erro.
- Os botões de "Sincronizar Discord" aparecem bloqueados, com o motivo no hover.
- Checkout e cotação de frete respondem "indisponível" em vez de chamar as APIs.
- E-mail não é enviado: vira arquivo em **`tmp/mails/`** (um por destinatário).
  É lá que está o link de recuperação de senha.

Para rodar **com** as credenciais reais do `.env` — depurar o Mercado Pago, por
exemplo — aponte só o arquivo base, o que desliga a fusão do override:

```bash
docker compose -f docker-compose.yml up
```

### Comandos do dia a dia

Sempre dentro do container:

```bash
docker compose exec web bin/rails test        # suíte completa
docker compose exec web bin/rails console     # console
docker compose exec web bin/rubocop           # lint
docker compose exec web bin/rails db:seed     # repovoar / resetar senhas de seed
docker compose exec web bundle install        # após mudar o Gemfile
docker compose exec web bin/rails db:prepare  # criar/migrar banco
```

O `.env` da raiz **nunca é commitado**. Sem ele o app sobe normalmente — só os
fluxos que dependem de cada serviço ficam indisponíveis.

> Rodar fora do Docker exige Ruby 3.4 e o cliente `psql` instalados por conta
> própria — o `schema_format = :sql` faz os comandos de banco dependerem dele.

## Testes e qualidade

`bin/rails test` roda a suíte inteira contra um Postgres de verdade, em paralelo
por processos. Nada de mock de banco.

O CI (`.github/workflows/ci.yml`) roda em todo push e PR:

| Job | O que faz |
|---|---|
| `lint` | RuboCop (rails-omakase) |
| `scan_ruby` | Brakeman (análise estática de segurança) + bundler-audit (CVEs nas gems) |
| `scan_js` | `importmap audit` (CVEs nas dependências JS) |
| `test` | Suíte completa contra PostgreSQL 17 |

## Deploy

Kamal 2 em VPS único: app + Postgres como acessório na mesma máquina, Active
Storage no Cloudflare R2, SSL Let's Encrypt no proxy do Kamal atrás do
Cloudflare. Jobs rodam dentro do Puma (`SOLID_QUEUE_IN_PUMA`), sem máquina
separada enquanto o volume não pedir.

O runbook completo — pré-requisitos, Cloudflare, rate limiting de borda,
webhooks, primeiro usuário de gestão, smoke test e rollback — está em
**[`docs/deploy.md`](docs/deploy.md)**.

## Estrutura

```
app/
  controllers/         API JSON pública + /admin (JSON) + /painel (HTML)
  models/              domínio; concerns compartilhados em models/concerns
  policies/            Pundit — uma policy por recurso
  notifiers/           Noticed: um evento, N canais de entrega
  jobs/                Solid Queue (Discord, etiquetas, alertas, analytics)
  services/            integrações externas (Mercado Pago, Melhor Envio, Discord)
  javascript/          Stimulus, carregado sob demanda via importmap
db/
  structure.sql        schema autoritativo (citext, CHECKs, triggers)
  migrate/
docs/
  deploy.md            runbook de produção
  discord-bot.md       configuração do bot e sincronização de cargos
```

## Documentação

- [`docs/deploy.md`](docs/deploy.md) — runbook de produção
- [`docs/discord-bot.md`](docs/discord-bot.md) — bot do Discord e cargos
- `LEDS_schema.sql` e `LEDS_Modelagem_de_Dados.md` — modelagem de dados
  autoritativa (fora deste repositório)

---

<sub>Projeto da Liga Acadêmica de Estrutura de Dados e Soluções — UNITAU, Taubaté/SP.</sub>
