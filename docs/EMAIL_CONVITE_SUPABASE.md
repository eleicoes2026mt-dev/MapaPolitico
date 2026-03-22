# E-mail de convite (assessores) – Supabase

## Por que o e-mail mostra `http://localhost:3000`?

O texto **“You have been invited to create a user on http://localhost:3000”** vem do **modelo padrão em inglês** do Supabase, que usa a variável **`{{ .SiteURL }}`**.  
Essa variável é preenchida com o que está em **Authentication → URL Configuration → Site URL**.

- **Não é o Flutter** que define essa frase no e-mail.
- Se **Site URL** estiver `http://localhost:3000`, **todo convite** vai mostrar localhost — mesmo com o app em produção na Vercel.

**Correção obrigatória (2 minutos):** altere o **Site URL** no painel (passo 1 abaixo). Depois disso, novos e-mails passam a mostrar o domínio certo (ou use o modelo da seção 2 que nem usa `SiteURL` no texto).

---

## 1. Site URL e Redirect URLs (obrigatório)

No **Supabase Dashboard** → seu projeto **mjmqadpqcatwgskywisk** (ou o que estiver em uso):

1. **Authentication** → **URL Configuration**.
2. **Site URL** → coloque **só** a URL pública do sistema (sem barra no final), por exemplo:
   - `https://web-liart-iota-22.vercel.app`  
   ou o domínio definitivo da campanha.
3. **Additional Redirect URLs** → adicione (uma por linha ou com curinga, conforme o painel permitir):
   - `https://web-liart-iota-22.vercel.app/**`
   - Se tiver outro domínio (ex.: `www`), inclua também.
4. Clique em **Save**.

> **Nunca** deixe **Site URL** como `http://localhost:3000` em projeto que já está em produção — isso é o que gera o e-mail errado.

O app já envia `redirect_to` com a URL de produção (`APP_URL` / Vercel); o **link “Accept invite”** (`{{ .ConfirmationURL }}`) depende também dessas URLs estarem na lista de redirect permitidas.

## 2. Template do e-mail de convite (recomendado)

Troque o modelo **Invite** padrão (que cita `{{ .SiteURL }}` e aparece em inglês com localhost):

1. **Authentication** → **Email Templates** → **Invite user**.
2. Cole um dos modelos abaixo (PT ou EN). Eles usam **`{{ .ConfirmationURL }}`** no botão/link — esse é o link real do sistema; **não** repetem `SiteURL` no texto, evitando confusão.

### Assunto (PT)
`Você foi convidado – CampanhaMT`

### Corpo em inglês (se os convidados usam Gmail em EN)

**Subject:** `You have been invited – CampanhaMT`

**Body (HTML):**

```html
<h2>You have been invited</h2>
<p>You have been invited to join <strong>CampanhaMT</strong> (electoral campaign management). Click below to set your password and access the system:</p>
<p><a href="{{ .ConfirmationURL }}" style="background:#2563eb;color:white;padding:10px 20px;text-decoration:none;border-radius:6px;display:inline-block;">Accept the invite</a></p>
<p>If the button does not work, copy this link into your browser:</p>
<p><a href="{{ .ConfirmationURL }}">{{ .ConfirmationURL }}</a></p>
<p>— CampanhaMT</p>
```

(Este modelo **não** usa `{{ .SiteURL }}` no parágrafo, então some a frase “create a user on http://localhost:3000”.)

### Corpo em português

**Assunto sugerido:**  
`Você foi convidado – CampanhaMT`

**Corpo (HTML):**

```html
<h2>Você foi convidado</h2>
<p>Olá,</p>
<p>Você foi convidado a participar do <strong>CampanhaMT – Gestão Eleitoral</strong> como <strong>assessor(a)</strong> ou <strong>apoiador(a)</strong> (o papel é definido no convite).</p>
<p>Clique no botão abaixo para criar sua senha e acessar o sistema:</p>
<p><a href="{{ .ConfirmationURL }}" style="background:#2563eb;color:white;padding:10px 20px;text-decoration:none;border-radius:6px;display:inline-block;">Aceitar convite</a></p>
<p>Se o botão não funcionar, copie e cole este link no navegador:</p>
<p><a href="{{ .ConfirmationURL }}">{{ .ConfirmationURL }}</a></p>
<p>Este link é válido por tempo limitado. Se não foi você quem solicitou, ignore este e-mail.</p>
<p>— CampanhaMT</p>
```

Variáveis úteis:

- `{{ .ConfirmationURL }}` – link para aceitar o convite (já usa a URL do app configurada no código e no Site URL).
- `{{ .Email }}` – e-mail do convidado.
- `{{ .SiteURL }}` – URL do site configurada no passo 1.

## 3. Variável de ambiente na Vercel (opcional)

Se quiser que a Edge Function use uma URL fixa mesmo quando o app não enviar:

1. No **Supabase Dashboard**: **Project Settings** → **Edge Functions** → **Secrets**.
2. Crie o secret: `REDIRECT_URL` = `https://web-liart-iota-22.vercel.app` (ou a URL do seu app).

Assim, se por algum motivo o app enviar localhost, o servidor usa essa URL no lugar.

## 4. O e-mail de convite não chega — o que fazer

O envio padrão do Supabase (sem SMTP próprio) tem **limite de taxa** e pode ir para **spam/promoções**. Para o time do deputado conseguir acesso:

1. **Link copiável no app**  
   Depois de **Convidar** ou **Reenviar convite**, o app pode abrir um diálogo com um **link longo**. Use **Copiar link** e envie pelo **WhatsApp** para o assessor — funciona como o e-mail (define senha e entra).

2. **Configurar SMTP (recomendado em campanha)**  
   No Dashboard: **Project Settings** → **Authentication** → **SMTP Settings**.  
   Use um provedor (SendGrid, Resend, Amazon SES, etc.) com domínio verificado. Assim os convites saem do seu domínio e costumam entregar melhor.

3. **Redirect URLs**  
   A URL do app (ex.: Vercel) **precisa** estar em **Authentication** → **URL Configuration** → **Redirect URLs** (inclua `https://seu-dominio.vercel.app/**`). Se faltar, o convite pode falhar ou o link quebrar.

4. **Conferir logs**  
   **Authentication** → **Users**: veja se o usuário foi criado. **Logs** do projeto: erros de Auth ou das Edge Functions `convidar-assessor` / `reenviar-convite-assessor`.

5. **Redeploy das Edge Functions**  
   Após alterar as funções no repositório, rode no projeto:  
   `supabase functions deploy convidar-assessor` e `supabase functions deploy reenviar-convite-assessor`.

## 5. Assessores já confirmaram o e-mail

Se o assessor **já definiu senha**, ele entra com e-mail + senha. Para nova senha: **Esqueci minha senha** na tela de login.

---

## 6. Convite para **apoiadores** (cadastro de votantes no mapa)

O fluxo é o mesmo do assessor (Auth **Invite** + template com `{{ .ConfirmationURL }}`), mas a Edge Function é outra:

- `convidar-apoiador` — candidato ou assessor envia convite; o usuário recebe role **apoiador** e fica vinculado à linha em `apoiadores.profile_id`.
- `reenviar-convite-apoiador` — reenvio quando ainda não há conta vinculada.

**Deploy (após `supabase login` e `supabase link`):**

```bash
supabase functions deploy convidar-apoiador
supabase functions deploy reenviar-convite-apoiador
```

No app: tela **Apoiadores** → ícones **Convidar** / **Reenviar** no cartão (com e-mail cadastrado e sem `profile_id`). O apoiador, após criar a senha, acessa **Votantes** e **Mapa** (menu reduzido).

### Template PT só para apoiador (opcional)

Se quiser um texto exclusivo, você pode duplicar o modelo **Invite** em um único projeto **não** é possível por tipo de convite; use o texto **genérico** acima (“assessor ou apoiador”) ou um texto neutro:

```html
<h2>Convite – CampanhaMT</h2>
<p>Olá,</p>
<p>Você foi convidado a acessar o <strong>CampanhaMT</strong> para acompanhar a campanha e cadastrar informações de apoio (incluindo votantes por cidade, quando aplicável).</p>
<p><a href="{{ .ConfirmationURL }}" style="background:#2563eb;color:white;padding:10px 20px;text-decoration:none;border-radius:6px;display:inline-block;">Criar senha e entrar</a></p>
<p>Se o botão não funcionar, copie o link: <a href="{{ .ConfirmationURL }}">{{ .ConfirmationURL }}</a></p>
<p>— CampanhaMT</p>
```
