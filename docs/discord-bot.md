# Bot do Discord — o que criar e por quê

Guia para colocar de pé a integração de **cargos** entre o site e o servidor do
Discord da LEDS. Escrito para quem nunca criou uma aplicação no Discord.

---

## 1. O que é — e o que NÃO é

**Não existe um "bot" para hospedar.** Nenhum processo precisa ficar rodando,
nenhum servidor a mais, nenhuma conta de nuvem nova.

O que existe é uma **aplicação registrada no Discord** que gera um **bot token**.
Esse token é uma credencial: com ele, o site do LEDS chama a API REST do Discord
direto do Rails para criar cargo, apagar cargo e dar/tirar cargo de uma pessoa.
É exatamente como o site já fala com o Mercado Pago ou com o Melhor Envio.

O que você vai criar aqui é, portanto:

| Você cria | Onde | Para quê |
|---|---|---|
| Uma aplicação | Portal de desenvolvedores do Discord | Existir |
| Um bot dentro dela | Aba **Bot** da aplicação | Gerar o token |
| Um convite | URL montada à mão | Botar o bot no servidor |
| Duas variáveis | `.env` do projeto | O site achar as credenciais |

Um bot **de verdade** — com comandos de barra, respondendo em canal, ouvindo
eventos — precisaria de um processo conectado ao *gateway*. Isso **não é
necessário** para nada do que os emblemas fazem, e está fora do escopo deste
documento.

---

## 2. Criar a aplicação e o bot

1. Entre em <https://discord.com/developers/applications> com a conta que
   administra o servidor da LEDS.
2. **New Application** → nome (ex.: `LEDS Emblemas`) → aceite os termos → **Create**.
3. No menu da esquerda, **Bot**.
4. Em **Token**, clique em **Reset Token** e **copie**. Ele aparece **uma vez
   só** — se perder, é só resetar de novo (o token antigo para de funcionar na
   hora).
5. Nada mais precisa ser ligado nessa tela. Em especial:
   - **Privileged Gateway Intents** (Presence, Server Members, Message Content):
     deixe **todos desligados**. Intents servem para o gateway, que não usamos.
   - **Public Bot**: pode desligar, para ninguém mais convidar seu bot.

> ⚠️ O token é uma senha. Ele vive no `.env`, que é ignorado pelo git. Nunca
> cole em issue, print ou mensagem. Se vazar, **Reset Token** imediatamente.

---

## 3. A permissão necessária

O bot precisa de **uma** permissão: **Manage Roles** (`Gerenciar Cargos`).

Valor numérico: **`268435456`**.

É só isso porque o site não lê mensagem, não entra em canal de voz e não expulsa
ninguém. Se um dia alguém pedir mais permissões "por garantia", a resposta é
não: um token com permissão de administrador que vaze compromete o servidor
inteiro.

---

## 4. A HIERARQUIA — a pegadinha que mais quebra

Esta é a causa nº 1 de "configurei tudo e não funciona".

No Discord, **um cargo só pode mexer em cargos ABAIXO dele na lista**. Ter a
permissão `Manage Roles` não basta: o cargo do bot precisa estar **acima** de
todos os cargos que ele vai gerenciar.

```
   Configurações do servidor → Cargos

   ┌─────────────────────────┐
   │ Presidência             │
   │ Diretoria               │
   │ LEDS Emblemas   ← O BOT │  ⬅ arraste para CÁ: acima de tudo que ele cria
   ├─────────────────────────┤
   │ Maratonista Ouro        │  ⬇ os cargos criados pelo site nascem no fim
   │ Maratonista Prata       │     da lista, então já ficam abaixo
   │ Lenda                   │
   │ @everyone               │
   └─────────────────────────┘
```

Se estiver errado, a API responde **403 Forbidden** mesmo com o token e a
permissão corretos — e a mensagem do Discord não diz que é hierarquia. O painel
do site traduz esse 403 apontando para este documento.

Quando o bot entra no servidor, o cargo dele é criado no **fim** da lista.
**Arraste para cima manualmente** logo depois de convidar.

---

## 5. Convidar o bot para o servidor

Monte a URL trocando `SEU_CLIENT_ID` pelo **Application ID** (aba *General
Information* da aplicação):

```
https://discord.com/api/oauth2/authorize?client_id=SEU_CLIENT_ID&scope=bot&permissions=268435456
```

Abra no navegador, escolha o servidor da LEDS, confirme. Depois **arraste o
cargo do bot para cima** (seção 4).

---

## 6. As duas variáveis de ambiente

No `.env` do projeto (veja `.env.example`):

```bash
DISCORD_BOT_TOKEN=o_token_da_secao_2
DISCORD_GUILD_ID=o_id_do_servidor
```

Para achar o **id do servidor** (guild id):

1. Discord → Configurações do usuário → Avançado → ligue **Modo desenvolvedor**.
2. Clique com o botão direito no nome do servidor → **Copiar ID do servidor**.

Sem essas duas variáveis, **tudo relacionado ao Discord fica desligado em
silêncio**: os botões aparecem opacos, e nenhuma chamada é feita. O site
funciona normalmente sem Discord — é uma decisão de projeto, não um acidente.

---

## 7. Cada chamada que o site faz

Base: `https://discord.com/api/v10`
Cabeçalho em todas: `Authorization: Bot <DISCORD_BOT_TOKEN>`

| # | Método e rota | Quando | Corpo | Resposta |
|---|---|---|---|---|
| 1 | `PUT /guilds/{guild}/members/{uid}/roles/{role}` | pessoa ganhou emblema/rank/elo | — | 204 |
| 2 | `DELETE /guilds/{guild}/members/{uid}/roles/{role}` | pessoa perdeu | — | 204 |
| 3 | `GET /guilds/{guild}/roles` | montar o diff no painel | — | lista de cargos |
| 4 | `POST /guilds/{guild}/roles` | criar cargo novo | `{name, color, mentionable}` | o cargo criado (com `id`) |
| 5 | `PATCH /guilds/{guild}/roles/{role}` | nome ou cor mudou no site | `{name, color}` | o cargo |
| 6 | `DELETE /guilds/{guild}/roles/{role}` | cargo órfão, com confirmação | — | 204 |
| 7 | `GET /guilds/{guild}/members/{uid}` | cross-check de uma pessoa | — | membro, com `roles` |

`{uid}` é o **snowflake do usuário no Discord**, que o site guarda em
`oauth_identities.uid` quando a pessoa vincula a conta.

**Cor:** o Discord guarda cor como **inteiro decimal**, não hexadecimal. O site
converte: `#00C55B` → `50523`.

Onde isso vive no código:
- `app/models/concerns/discord_rest.rb` — monta a requisição e classifica a resposta
- `app/jobs/discord_cargo_job.rb` — chamadas 1 e 2, por evento, em background
- `app/services/discord_sync.rb` — chamadas 3 a 7, pelos botões de sincronizar

---

## 8. Os dois fluxos de sincronização

### A. "Sincronizar emblemas" — botão do usuário
`Meu perfil → Emblemas`. Só fica ativo com a conta do Discord vinculada.

1. Lê os cargos atuais da pessoa (chamada 7).
2. Monta o que ela **deveria** ter: os cargos dos emblemas que possui, do rank
   alcançado em cada um e do elo atual.
3. Aplica só a diferença — dá o que falta (1), tira o que sobrou (2).

**Restrito aos cargos que o site criou.** Um cargo de moderação que a pessoa
tenha nunca é removido, mesmo não estando na lista do site.

Isto é uma **rede de segurança**: os eventos já sincronizam ao ganhar e ao
perder. O botão existe para quando um evento falhou — bot fora do ar, conta
vinculada só depois, cargo apagado à mão.

### B. "Sincronizar cargos" — botão da gestão
`Gestão → Emblemas → Sincronizar cargos`, que leva a `Gestão → Discord`.

Só entram os itens marcados com **"espelhar no Discord"** (emblema, rank ou elo).
A tela mostra o diff **antes de escrever qualquer coisa**:

- **Criar** — marcado e ainda sem cargo no servidor
- **Atualizar** — o cargo existe, mas o nome ou a cor mudaram no site
- **Apagar** — cargo que o site criou e que nenhum item marcado reivindica mais

Dois botões: *Criar e atualizar* (inofensivo) e *Aplicar e apagar os órfãos*
(pede confirmação). **Apagar cargo no Discord é irreversível e tira de todo
mundo que o tinha, na hora** — por isso nunca acontece sem clique explícito.

> **Como o site sabe o que é dele:** toda vez que cria um cargo, ele registra o
> id na tabela `discord_cargos`. **Só apaga id que está lá.** Sem esse registro,
> apagar um emblema no site levaria junto a informação de qual cargo era nosso,
> e "limpar os órfãos" viraria apagar cargo de moderação.

---

## 9. Limites e erros

O Discord limita chamadas por rota. O site trata assim:

| Resposta | Significado | O que o site faz |
|---|---|---|
| **429** | passou do limite | recua e repete (até 5 vezes, com espera crescente) |
| **4xx** | erro permanente | **descarta** — repetir não resolve |
| **5xx** | Discord com problema | recua e repete |

Erros que você vai encontrar de verdade:

| Código | Causa quase certa | Solução |
|---|---|---|
| **401** | token errado ou resetado | copie o token de novo (seção 2) |
| **403** | **hierarquia** | arraste o cargo do bot para cima (seção 4) |
| **404** em cargo | apagado à mão no servidor | sincronize: o site recria e reconcilia |
| **404** em membro | a pessoa saiu do servidor | nada a fazer; ela vinculou mas não está lá |
| **50013** (no corpo) | `Missing Permissions` | é hierarquia também, quase sempre |

Criar cargo tem limite **rígido**: 250 cargos por servidor. Por isso o site pede
que você **marque** o que deve virar cargo, em vez de espelhar tudo.

---

## 10. Como testar sem estragar o servidor de verdade

1. Crie um **servidor pessoal** no Discord (grátis, leva 10 segundos).
2. Convide o bot nele (seção 5) e arraste o cargo do bot para o topo.
3. Ponha o **id desse servidor** em `DISCORD_GUILD_ID` no `.env` local.
4. Vincule sua conta do Discord no site (Meu perfil → Informações).
5. No painel, marque um emblema com "espelhar no Discord".
6. `Gestão → Discord` → deve listar **Criar: 1** → aplique → o cargo aparece no
   seu servidor de teste.
7. Conceda o emblema a você mesmo e clique em **Sincronizar emblemas** no perfil
   → você recebe o cargo.
8. Desmarque o emblema → o diff mostra o cargo em **Apagar**.

Quando estiver satisfeito, troque `DISCORD_GUILD_ID` para o servidor real.

---

## 11. Checklist final

- [ ] Aplicação criada no portal de desenvolvedores
- [ ] Token gerado e copiado para `DISCORD_BOT_TOKEN`
- [ ] Nenhum *privileged intent* ligado
- [ ] Bot convidado com `permissions=268435456`
- [ ] **Cargo do bot arrastado para acima dos cargos que ele gerencia**
- [ ] Modo desenvolvedor ligado, id do servidor em `DISCORD_GUILD_ID`
- [ ] `Gestão → Discord` abre sem o aviso de "não configurado"
- [ ] Um cargo de teste criado e apagado pelo painel
