# Deploy — Sistema LEDS (Kamal 2 + Cloudflare + R2)

Runbook de produção. VPS único, **Postgres externo** (container próprio,
compartilhado com outras aplicações — o Kamal não o gerencia), Active Storage no
Cloudflare R2, SSL do proxy Kamal atrás do Cloudflare.

## 1. Pré-requisitos

- VPS Linux (Docker instalado ou o Kamal instala) — anote o IP.
- **Container Postgres já rodando na VPS**, com a rede e os bancos preparados
  conforme a §1.1 abaixo.
- Domínio apontado ao Cloudflare (ex.: `loja.leds.unitau.br`).
- Bucket Cloudflare R2 + par de chaves (Access Key / Secret) + endpoint
  `https://<account_id>.r2.cloudflarestorage.com`.
- Conta no `ghcr.io` + Personal Access Token com `write:packages`.
- Provedor SMTP (address/port/user/pass).
- Credenciais reais: Google/Discord OAuth (redirect URIs de produção!), Discord
  webhook + bot token, VAPID (`WebPush.generate_key`), Mercado Pago (produção),
  Melhor Envio (produção, `MELHOR_ENVIO_SANDBOX=false`, CPF do responsável).

### 1.1 Postgres externo — o que preparar na VPS

O banco NÃO é gerenciado pelo Kamal. Ele roda num container próprio, que pode
servir outras aplicações. Três coisas precisam estar prontas antes do primeiro
deploy.

**a) A rede docker `kamal`, com o Postgres dentro dela.**

O Kamal roda todo container do app na rede `kamal` — isso é fixo no gem, não há
opção de configuração. Logo, é o container do Postgres que entra nessa rede; aí
o `DB_HOST` passa a ser o nome dele, resolvido pelo DNS interno do Docker.

```bash
# na VPS — a rede é criada pelo kamal, mas pode ser criada antes; é idempotente
docker network inspect kamal >/dev/null 2>&1 || docker network create kamal

docker network connect kamal <nome-do-container-do-postgres>
```

Um `docker compose down/up` na stack do banco **recria** o container e desfaz
essa ligação. Para não depender de lembrar disso, declare a rede como externa no
compose **do Postgres**:

```yaml
services:
  postgres:                 # use o nome real do serviço
    networks: [ default, kamal ]

networks:
  kamal:
    external: true
```

O hook `.kamal/hooks/pre-deploy` verifica isso a cada deploy e para com o
comando exato se a ligação tiver caído — em vez de deixar o deploy falhar lá na
frente com "container failed to start".

**b) Role e bancos.** O app usa **quatro** bancos (primary + a trifecta do
Solid). Conectado ao Postgres da VPS:

```sql
CREATE ROLE site_leds LOGIN PASSWORD 'a-mesma-de-POSTGRES_PASSWORD';

CREATE DATABASE site_leds_production        OWNER site_leds;
CREATE DATABASE site_leds_production_cache  OWNER site_leds;
CREATE DATABASE site_leds_production_queue  OWNER site_leds;
CREATE DATABASE site_leds_production_cable  OWNER site_leds;
```

Alternativa: `ALTER ROLE site_leds CREATEDB;` e deixar o `db:prepare` criar os
quatro sozinho no primeiro boot. Num Postgres compartilhado, criar à mão dá mais
controle sobre quem pode criar o quê.

> As extensões que o schema usa (`citext`) exigem superusuário na primeira vez.
> Se o `db:prepare` reclamar de permissão, rode uma vez como superusuário:
> `CREATE EXTENSION IF NOT EXISTS citext;` **dentro de `site_leds_production`**.

**c) O Postgres precisa aceitar conexão da rede docker.** A imagem oficial já
escuta em `0.0.0.0` e usa `scram-sha-256` — normalmente não há nada a fazer. Se
for um Postgres customizado, confira `listen_addresses` e a linha de `pg_hba.conf`
que cobre a faixa da rede `kamal`.

**Conferindo antes de deployar:**

```bash
# na VPS: o app enxerga o banco pelo nome?
docker run --rm --network kamal postgres:17 \
  pg_isready -h <nome-do-container-do-postgres> -U site_leds
```

### 1.2 Máquina de deploy — WSL2 no Windows

O `kamal` roda na SUA máquina, não na VPS: ele faz o build da imagem, dá push no
registro e conversa com o servidor por SSH. Os hooks (`.kamal/hooks/`) também
rodam aqui — são scripts `sh`, e é por isso que WSL2 é o caminho e não o
PowerShell.

**Uma vez, dentro do WSL:**

```bash
sudo apt update
sudo apt install -y ruby-full build-essential   # ruby-dev é necessário: o kamal
                                                # puxa ed25519/bcrypt_pbkdf, que
                                                # compilam extensão nativa
gem install --user-install kamal -v 2.12.0      # mesma versão do Gemfile.lock
echo 'export PATH="$(ruby -e "puts Gem.user_dir")/bin:$PATH"' >> ~/.bashrc
exec bash

kamal version   # deve imprimir 2.12.0
```

Não é preciso instalar as gems do app: o `kamal` é standalone e o Rails só roda
dentro do container. Por isso use o comando `kamal` direto, **não** o `bin/kamal`
do repositório (aquele é um binstub do bundler e ia querer o Gemfile inteiro).

**Onde clonar o repositório:** dentro do filesystem do WSL (`~/site-leds`), não
em `/mnt/c/...`. O Kamal manda o diretório de trabalho inteiro como contexto de
build, e ler isso através da fronteira Windows↔WSL é ordens de grandeza mais
lento — ainda mais em pasta sincronizada pelo OneDrive.

```bash
cd ~ && git clone https://github.com/ledsunitau/site-leds.git
cd site-leds
```

O fluxo passa a ser: desenvolve no Windows → `git push` → no WSL `git pull` →
`kamal deploy`. O Kamal usa o SHA do commit como versão da imagem e avisa se
houver alteração não commitada, então o que sobe é sempre um commit real.

**Ainda no WSL:**

- **Docker**: habilite a integração do Docker Desktop com a distro
  (Settings → Resources → WSL Integration). Confira com `docker version`.
- **Chave SSH** com acesso root (ou sudo) na VPS, em `~/.ssh`. Teste:
  `ssh root@<IP_DA_VPS> docker version`.
- **`.env.production`** na raiz do clone, **fora do git** (já está no
  `.gitignore` via `.env*`). É o arquivo da §2.

## 2. Preencher os placeholders

- `config/deploy.yml`: **não tem mais placeholder para editar.** IP e domínio
  saem do ambiente, via ERB — o Kamal renderiza ERB no arquivo antes de parsear
  o YAML:

  ```yaml
  servers:
    web:
      - <%= ENV.fetch("VPS_IP") %>
  proxy:
    host: <%= ENV.fetch("APP_HOST") %>
  ```

  `ENV.fetch` sem default de propósito: variável ausente estoura no ato, com o
  nome dela na mensagem (`KeyError: key not found: "VPS_IP"`), em vez de virar
  host vazio e falhar dez passos depois.

  Note que o **domínio é o `APP_HOST`**, não uma variável separada: o proxy emite
  o certificado para esse host e o app usa o mesmo valor nos links de e-mail e nas
  back_urls do Mercado Pago. São obrigatoriamente iguais.

  O owner da imagem já está resolvido (`ledsunitau`, confere com o remote). Não
  há `accessories:` — o banco é externo (§1.1).
- ENV do operador (o `.kamal/secrets` lê daqui). Crie um `.env.production` **fora
  do git** e exporte antes de deployar:

  ```bash
  set -a; source .env.production; set +a
  ```

  Deve conter tudo listado em `.kamal/secrets` (senhas, tokens, R2, SMTP, OAuth,
  `KAMAL_REGISTRY_USERNAME/PASSWORD`) mais:

  | Variável | Para quê |
  |---|---|
  | `VPS_IP` | host do `servers.web` (lido só pelo deploy.yml, não pelo app) |
  | `APP_HOST` | domínio: certificado do proxy + links do mailer + back_urls do MP |
  | `DB_HOST` | nome do **container** do Postgres na rede `kamal` |
  | `DB_PORT` | opcional — vazio usa 5432 |
  | `POSTGRES_USER` / `POSTGRES_PASSWORD` | role dona dos 4 bancos |

  `.env.example` tem a lista completa comentada.

## 3. Cloudflare

- **DNS**: registro A do domínio → IP do VPS.
- **SSL/TLS**: **Full (Strict)** — o proxy Kamal serve um certificado Let's Encrypt
  válido no origin, então dá para exigir Strict (fecha MITM entre CF e o servidor).
  "Full" (sem Strict) também funciona.

> **Ordem importa no PRIMEIRO deploy.** O proxy do Kamal (`ssl: true`) emite o
> certificado pelo Let's Encrypt, e o desafio precisa chegar até a VPS. Com a
> nuvem LARANJA ligada, quem atende o Let's Encrypt é o Cloudflare, não o seu
> servidor — e a emissão pode falhar antes de existir qualquer certificado.
>
> Caminho seguro: deixe o registro em **DNS only (nuvem cinza)** para o
> `kamal setup`, confirme que o certificado saiu, e só então ligue a nuvem
> laranja. Verificação:
>
> ```bash
> kamal proxy logs | grep -i "certificate\|acme"      # sem erro de ACME
> curl -sI https://<APP_HOST>/up | head -1            # 200 direto no origin
> ```
>
> Antes disso, confira que **80 e 443 estão abertos** no firewall da VPS — o
> proxy publica as duas, e a 80 é usada tanto pelo redirect quanto pelo desafio.
>
> Se mais para frente uma RENOVAÇÃO falhar com a nuvem laranja ligada, a saída
> definitiva é trocar o Let's Encrypt por um **Origin Certificate** do Cloudflare
> (15 anos, gratuito): o Kamal aceita certificado próprio em
> `proxy.ssl.certificate_pem` / `private_key_pem`, lidos dos secrets.

### 3.1 Rate limiting — camada 1 de borda (RNF-15)

A camada 2 (aplicação) é o `Rack::Attack` (`config/initializers/rack_attack.rb`).
A camada 1 é por IP na borda do Cloudflare — configurar em **Security → WAF →
Rate limiting rules**. Deliverable explícito (não fica implícito):

| Regra | Match (URI Path) | Limite sugerido | Ação |
|---|---|---|---|
| Global | qualquer (`/*`) | 600 / 1 min por IP | Managed Challenge |
| Login | `/users/sign_in` | 15 / 1 min por IP | Block 10 min |
| Cadastro/senha | `/users`, `/users/password` | 10 / 1 h por IP | Block |
| Webhook pagamento | `/pagamentos/webhook` | 240 / 1 min por IP | Block |
| Cotação/checkout (API paga) | `/frete/cotar`, `/checkout` | 60 / 1 min por IP | Managed Challenge |
| Escrita pública | `/events`, `/consents`, `/parceria_leads`, `/ideias` | 60 / 1 h por IP | Block |
| Comentários/denúncias | `/posts/*/comentarios`, `/comentarios/*/denuncias` | 60 / 1 h por IP | Block |

Limites de borda ficam **acima** dos do Rack::Attack (a borda corta abuso
grosso; a aplicação afina por rota/usuário). Ajuste conforme o tráfego real.

### 3.2 Cache de HTML — NÃO ligue "Cache Everything"

O padrão do Cloudflare (cachear só extensões estáticas, HTML sempre no origin)
é o certo aqui. **Não** crie regra de "Cache Everything"/"Cache Level: Everything"
sobre as páginas sem ler o parágrafo abaixo.

As listagens públicas (`/acoes`, `/posts`, `/produtos/todos`) respondem **dois
corpos na mesma URL**: a página inteira, ou só o fragmento da lista quando o
Turbo manda o header `Turbo-Frame` (é o que faz clicar num chip trocar só a
grade, sem recarregar navbar e footer). O app declara isso no
`Vary: Accept, Turbo-Frame`, e um cache que respeite `Vary` fica correto.

O risco é ligar "Cache Everything" **junto** com qualquer coisa que ignore ou
normalize o `Vary` — aí o CF pode servir o fragmento (sem navbar, sem footer,
sem `<html>`) para quem abriu o endereço no navegador. Sintoma: a página aparece
"pelada", só a lista de cards. Se precisar cachear HTML, exija que a regra
preserve o `Vary` e teste com:

```bash
curl -sI https://<APP_HOST>/acoes | grep -i '^vary'
# esperado: vary: Accept, Turbo-Frame
curl -s  https://<APP_HOST>/acoes | head -1
# esperado: <!DOCTYPE html>   (e NÃO <turbo-frame ...>)
```

### 3.3 Integrações externas (callbacks e webhooks — apontar pro domínio real)

Trocando `<APP_HOST>` pelo domínio de produção:

- **OAuth** (senão dá `redirect_uri_mismatch`): cadastre as URIs de callback nos
  consoles:
  - Google: `https://<APP_HOST>/users/auth/google_oauth2/callback`
  - Discord: `https://<APP_HOST>/users/auth/discord/callback`
- **Mercado Pago** (RF-LOJ-12): no painel, notification_url =
  `https://<APP_HOST>/pagamentos/webhook`. **Crie o webhook secret** e ponha em
  `MERCADO_PAGO_WEBHOOK_SECRET` — sem ele o webhook confia só no re-fetch (perde a
  validação de assinatura HMAC).
- **Melhor Envio** (RF-LOJ-11): `MELHOR_ENVIO_SANDBOX=false` e token de produção;
  o rastreio é ativo (o app consulta o ME), não precisa de webhook de entrada.

## 4. Deploy

Com a §1.1 pronta e o `.env.production` exportado:

```bash
kamal setup          # 1ª vez: instala docker, sobe proxy e app
kamal variantes      # uma vez: gera as variantes de imagem que faltarem (§4.2)

kamal deploy         # daí em diante, só isto
```

**Migração é automática — não há passo manual.** Duas coisas cuidam disso:

1. `.kamal/hooks/pre-deploy` roda antes do container novo subir e confirma que o
   Postgres externo está alcançável na rede `kamal`. Se não estiver, o deploy
   para ali, com o comando de correção — em vez de falhar depois num health
   check obscuro.
2. `bin/docker-entrypoint` executa `db:prepare` no boot do container, porque o
   `CMD` termina em `./bin/rails server` (é a condição que o script testa). Como
   o proxy só manda tráfego depois do health check, a migração acontece antes de
   qualquer request.

`db:prepare` é idempotente: cria o que falta, migra o que está pendente, não faz
nada se estiver tudo em dia. O alias `kamal prepare` continua existindo para
rodar à mão — útil depois de um `kamal deploy --skip-hooks`, ou para diagnóstico.

> **Correção:** uma versão anterior deste runbook dizia que "o Kamal não migra
> sozinho" e mandava rodar `kamal prepare` a cada deploy com migração. Estava
> errado — o entrypoint já fazia isso desde sempre. O passo manual era
> desnecessário (inofensivo, mas desnecessário).

- **Erros no log durante o `setup`**: se os bancos ainda não existirem, o Solid
  Queue embutido no Puma loga erro de conexão à base `queue` até o `db:prepare`
  do entrypoint terminar. É transitório. Se persistir, o problema é permissão —
  ver §1.1(b).
- As 4 bases do Solid Trifecta vivem no mesmo Postgres (ver `config/database.yml`).
  `queue`/`cable` usam `schema_format: ruby` (schemas dos gems); não esqueça —
  sem isso o `db:prepare` deixaria esses bancos vazios.
- **Rede do banco**: se o container do Postgres for recriado, ele sai da rede
  `kamal` e o próximo deploy para no hook. A correção definitiva é a rede externa
  no compose dele — §1.1(a).
- **Jobs**: rodam no Puma (`SOLID_QUEUE_IN_PUMA=true`). Quando a loja gerar
  volume, descomente o role `job:` no `deploy.yml` e mova para máquina dedicada.

### 4.1 Primeiro gestor (OBRIGATÓRIO — senão o /admin nasce inacessível)

O seed NÃO cria usuários em produção (fundadores são só dev/test). Sem um usuário
de gestão, ninguém acessa `/admin` (o gate é `current_user.gestao?`, i.e. role
`diretoria`/`presidencia`). Crie o primeiro via console — o gate é só o role:

```bash
kamal console
# no console:
User.create!(name: "Presidência LEDS", email: "presidencia@SEU_DOMINIO",
             password: "TROCAR_DEPOIS", role: "presidencia")
```

Depois entre com essa conta, promova os demais e troque a senha pela tela de
admin/perfil (RF-ADM-03). O cargo/histórico detalhado (Member/Mandato) também é
cadastrado por lá — o role acima já basta para abrir o `/admin`.

### 4.2 Variantes de imagem (Active Storage)

Nenhuma tela serve mais o arquivo original: avatar, card e galeria pedem uma
**variante** redimensionada em WebP (`:avatar` 96px, `:card` 640px, `:full`
1200px). Uma foto de celular de 4 MB deixa de ser baixada inteira dentro de um
avatar de 40 px.

O que isso exige em produção — tudo já configurado, listado aqui para conferência:

- **libvips** no container: já está no `Dockerfile` de produção (linha do
  `apt-get install`). Sem ele o `image_processing` cai no `rescue` e as imagens
  voltam a sair no tamanho original — degrada, não quebra.
- **Solid Queue rodando**: os anexos são declarados com `preprocessed: true`, ou
  seja, subir uma imagem enfileira um `ActiveStorage::TransformJob`. Com
  `SOLID_QUEUE_IN_PUMA=true` isso já acontece dentro do próprio web.
- **Espaço no R2**: cada imagem passa a ter 1–2 objetos derivados além do
  original, no mesmo bucket. São arquivos pequenos (WebP q80), mas o número de
  objetos cresce.

**Registros antigos não têm variante.** Eles não quebram — o Active Storage gera
sob demanda —, mas a geração acontece *dentro do request do primeiro visitante*.
Numa página de catálogo isso vira uma dúzia de conversões em série. Por isso o
passo de deploy:

```bash
kamal variantes      # = bin/rails imagens:preparar_variantes
```

Idempotente e seguro de repetir: variante que já existe é reaproveitada, e um
blob corrompido é registrado no log sem abortar o resto. Rode uma vez no primeiro
deploy depois desta versão; nos seguintes só se tiver importado imagens por fora
do app.

## 5. Smoke test pós-deploy

- [ ] `GET https://<dominio>/up` → 200 (health check).
- [ ] **O app está falando com o Postgres externo, e só com ele.**
      `kamal app exec "bin/rails runner 'puts ActiveRecord::Base.connection.execute(%q{select current_database(), inet_server_addr()}).first'"`
      deve devolver `site_leds_production` e o IP do container do banco na rede
      `kamal`. E `docker ps` na VPS não deve mostrar nenhum Postgres novo criado
      pelo deploy — se aparecer um `site_leds-db`, sobrou `accessories:` no
      `deploy.yml`.
- [ ] **As 4 bases existem e migraram**: `kamal app exec "bin/rails runner 'puts ActiveRecord::Base.connection.migration_context.needs_migration?'"`
      → `false`.
- [ ] Login por e-mail/senha e por Google/Discord (redirect URIs de produção).
- [ ] Recuperação de senha envia e-mail (SMTP).
- [ ] Upload de imagem de produto → aparece servida do R2.
- [ ] **Imagem sai como variante, não como original**: no DevTools → Network, a
      `src` dos cards e avatares deve ser `/rails/active_storage/representations/…`.
      Se vier `/rails/active_storage/blobs/…`, o libvips não está disponível ou o
      anexo não é rasterizável (SVG cai no original de propósito).
- [ ] **Listagens filtram e paginam**: em `/acoes` e `/posts`, clicar num chip e
      numa página troca só a grade (sem recarregar a folha de estilo — confira no
      Network) e a URL acompanha o filtro. Buscar por algo que está na 2ª página
      tem que encontrar.
- [ ] **`Vary` correto** (só importa se você cacheia HTML no CF — ver §3.2):
      `curl -sI https://<dominio>/acoes | grep -i '^vary'` → `Accept, Turbo-Frame`.
- [ ] Webhook do Mercado Pago alcança `/pagamentos/webhook` (configure a
      notification_url no painel MP com o domínio real; `APP_HOST` correto).
- [ ] Cotação de frete (`/frete/cotar`) responde com credenciais reais do ME.
- [ ] `kamal app logs -f` sem erros; jobs processando (Mission Control em
      `/admin/jobs`).

## 6. Rollback

```bash
kamal rollback       # volta para a versão anterior da imagem
```
