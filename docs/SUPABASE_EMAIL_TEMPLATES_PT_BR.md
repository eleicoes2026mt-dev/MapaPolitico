# Templates de e-mail Supabase (PT-BR) – CampanhaMT

Configure em **Supabase Dashboard** → **Authentication** → **Email Templates**.

Variáveis comuns do GoTrue (podem variar ligeiramente conforme a versão):

| Variável | Uso |
|----------|-----|
| `{{ .ConfirmationURL }}` | Link mágico (convite, confirmação, reset — conforme o template) |
| `{{ .Token }}` | Código OTP (se usares fluxo por código) |
| `{{ .SiteURL }}` | Site URL do projeto (evita no texto se ainda for localhost em dev) |
| `{{ .Email }}` | E-mail do destinatário |

**Site URL e Redirect URLs:** ver [EMAIL_CONVITE_SUPABASE.md](./EMAIL_CONVITE_SUPABASE.md).

Para **redefinição de senha** na web, o app usa redirect com hash, por exemplo:

`https://SEU_DOMINIO.vercel.app/#/redefinir-senha`

Inclui em **Additional Redirect URLs** (ou curinga `https://SEU_DOMINIO.vercel.app/**`).

---

## 1. Redefinir senha (Reset password)

**Nome no painel:** *Reset Password* / *Magic Link* (conforme o teu projeto).

### Assunto (Subject)

```
Redefinir sua senha – CampanhaMT
```

Alternativas curtas:

- `CampanhaMT: link para nova senha`
- `Solicitação de nova senha – Gestão Eleitoral MT`

### Corpo (HTML) – PT-BR

```html
<h2>Redefinir senha</h2>
<p>Olá,</p>
<p>Recebemos um pedido para criar uma <strong>nova senha</strong> na sua conta do <strong>CampanhaMT – Gestão Eleitoral</strong>.</p>
<p>Clique no botão abaixo. Na página que abrir, digite a nova senha e confirme.</p>
<p><a href="{{ .ConfirmationURL }}" style="background:#2563eb;color:#fff;padding:12px 22px;text-decoration:none;border-radius:8px;display:inline-block;font-weight:600;">Definir nova senha</a></p>
<p>Se o botão não funcionar, copie e cole este link no navegador:</p>
<p style="word-break:break-all;"><a href="{{ .ConfirmationURL }}">{{ .ConfirmationURL }}</a></p>
<p><small>Este link expira em pouco tempo. Se você <strong>não</strong> pediu redefinição, ignore este e-mail — sua senha atual permanece a mesma.</small></p>
<p>— Equipe CampanhaMT</p>
```

### Pré-visualização (texto plano, se o painel tiver campo “Plain”)

```
CampanhaMT – Redefinir senha

Use o link abaixo para definir uma nova senha:
{{ .ConfirmationURL }}

Se você não solicitou, ignore este e-mail.
```

---

## 2. Convite de utilizador (Invite)

Assunto e HTML completos em **[EMAIL_CONVITE_SUPABASE.md](./EMAIL_CONVITE_SUPABASE.md)** (secção “Corpo em português”).

**Assunto (resumo):** `Você foi convidado – CampanhaMT`

---

## 3. Confirmar inscrição (opcional)

Se usares confirmação por e-mail no registo:

### Assunto

```
Confirme seu e-mail – CampanhaMT
```

### Corpo (HTML)

```html
<h2>Confirme seu e-mail</h2>
<p>Olá,</p>
<p>Obrigado por se cadastrar no <strong>CampanhaMT</strong>. Para ativar sua conta, clique no link abaixo:</p>
<p><a href="{{ .ConfirmationURL }}" style="background:#2563eb;color:#fff;padding:12px 22px;text-decoration:none;border-radius:8px;display:inline-block;font-weight:600;">Confirmar e-mail</a></p>
<p>Ou copie o link:<br/><a href="{{ .ConfirmationURL }}">{{ .ConfirmationURL }}</a></p>
<p>— CampanhaMT</p>
```

---

## 4. Magic link (login sem senha) – se ativares

### Assunto

```
Seu link de acesso – CampanhaMT
```

### Corpo (HTML)

```html
<h2>Link de acesso</h2>
<p>Clique para entrar no <strong>CampanhaMT</strong>:</p>
<p><a href="{{ .ConfirmationURL }}" style="background:#2563eb;color:#fff;padding:12px 22px;text-decoration:none;border-radius:8px;display:inline-block;font-weight:600;">Entrar</a></p>
<p><a href="{{ .ConfirmationURL }}">{{ .ConfirmationURL }}</a></p>
<p>Se não foi você, ignore este e-mail.</p>
```

---

## 5. Como o e-mail “chama” o projeto

- **Nome da marca no assunto:** sempre **CampanhaMT** (ou **CampanhaMT – Gestão Eleitoral**).
- **Remetente (“From”):** em **Project Settings** → **Auth** (ou **SMTP** / **Resend**), configura nome amigável, ex.: `CampanhaMT <no-reply@seudominio.com>`.
- O **Site URL** do Supabase não substitui o assunto; só influencia links se usares `{{ .SiteURL }}` no template.

---

## 6. Comportamento no app (reset de senha)

- Fluxo **PKCE** devolve `?code=` na URL; o app deteta sessão de **recuperação** no JWT e abre **`/redefinir-senha`** mesmo que o hash antigo fosse `#/apoiadores`.
- O `redirectTo` enviado pelo app na web inclui **`/#/redefinir-senha`** — mantém a lista de **Redirect URLs** alinhada com o domínio de produção.
