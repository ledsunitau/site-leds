# Deploy — Sistema LEDS (Kamal 2 + Cloudflare + R2)

Runbook do `feature/deploy-producao`. VPS único, Postgres acessório na mesma
máquina, Active Storage no Cloudflare R2, SSL do proxy Kamal atrás do Cloudflare.

## 1. Pré-requisitos

- VPS Linux (Docker instalado ou o Kamal instala) — anote o IP.
- Domínio apontado ao Cloudflare (ex.: `loja.leds.unitau.br`).
- Bucket Cloudflare R2 + par de chaves (Access Key / Secret) + endpoint
  `https://<account_id>.r2.cloudflarestorage.com`.
- Conta no `ghcr.io` + Personal Access Token com `write:packages`.
- Provedor SMTP (address/port/user/pass).
- Credenciais reais: Google/Discord OAuth (redirect URIs de produção!), Discord
  webhook + bot token, VAPID (`WebPush.generate_key`), Mercado Pago (produção),
  Melhor Envio (produção, `MELHOR_ENVIO_SANDBOX=false`, CPF do responsável).

## 2. Preencher os placeholders

- `config/deploy.yml`: os `TODO:` restantes são **IP do VPS** (`servers.web` e
  `accessories.db.host`) e **domínio** (`proxy.host`). O owner da imagem já está
  resolvido (`ledsunitau`, confere com o remote do repositório).
- ENV do operador (o `.kamal/secrets` lê daqui). Crie um `.env.production` **fora
  do git** e exporte antes de deployar:

  ```bash
  set -a; source .env.production; set +a
  ```

  Deve conter tudo listado em `.kamal/secrets` (senhas, tokens, R2, SMTP, OAuth,
  `KAMAL_REGISTRY_USERNAME/PASSWORD`, `APP_HOST`, `POSTGRES_PASSWORD`).

## 3. Cloudflare

- **DNS**: registro A do domínio → IP do VPS, **proxied** (nuvem laranja).
- **SSL/TLS**: **Full (Strict)** — o proxy Kamal serve um certificado Let's Encrypt
  válido no origin, então dá para exigir Strict (fecha MITM entre CF e o servidor).
  "Full" (sem Strict) também funciona.

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

```bash
kamal setup          # 1ª vez: provisiona proxy, registro, sobe app + acessório db
kamal prepare        # cria/migra as 4 bases (primary + solid cache/queue/cable)
kamal variantes      # gera as variantes de imagem que faltarem (ver 4.2)

kamal deploy         # deploys subsequentes
kamal prepare        # ...seguido disto SEMPRE que o deploy trouxer migração
```

> **Este deploy traz migração.** `20260826160000_indices_das_listagens_publicas`
> cria três índices compostos — `acoes(status, created_at DESC)`,
> `posts(status, published_at DESC)` e `produtos(status, nome)` — que sustentam
> filtro + ordenação + `LIMIT` das listagens paginadas. São `CREATE INDEX`
> simples, sem reescrita de tabela; em tabela pequena roda em milissegundos.
> Sem eles o site funciona igual, só faz sort de tudo para devolver 24 linhas.
>
> O Kamal **não** migra sozinho (os hooks em `.kamal/hooks/` são todos
> `.sample`, inativos). `kamal prepare` é o passo manual, e `db:prepare` é
> idempotente: cria o que falta, migra o que está pendente, não faz nada se
> estiver tudo em dia.

- **Erros no log durante o `setup`**: o Puma sobe com o Solid Queue embutido
  ANTES do `db:prepare`, então o supervisor loga erro de conexão na base `queue`
  (ainda inexistente) até você rodar o `prepare`. É transitório — rode o
  `prepare` logo em seguida e os erros somem. O `/up` já responde 200 antes disso.
- As 4 bases do Solid Trifecta vivem no mesmo Postgres (ver `config/database.yml`).
  `queue`/`cable` usam `schema_format: ruby` (schemas dos gems); não esqueça —
  sem isso o `db:prepare` deixaria esses bancos vazios.
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
