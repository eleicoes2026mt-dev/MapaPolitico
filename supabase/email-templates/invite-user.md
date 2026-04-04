# E-mail de convite (Auth) — CampanhaMT

## Importante

O texto do e-mail **não muda sozinho** ao fazer deploy das Edge Functions. É obrigatório **copiar** o assunto e o corpo abaixo para o painel Supabase (**Authentication → Email Templates → Invite user**) e clicar em **Save**. Enquanto isso não for feito, continuará a aparecer o modelo em inglês “You have been invited”.

As Edge Functions `convidar-assessor`, `convidar-apoiador`, `reenviar-convite-*` enviam `user_metadata` usada nos templates abaixo:

| Chave | Significado |
|--------|-------------|
| `invite_kind` | `assessor` ou `apoiador` |
| `full_name` | Nome de quem recebe o convite |
| `candidato_nome` | Nome do candidato (campanha) |
| `convidante_nome` | Quem disparou o convite |
| `convidante_papel` | `candidato` ou `assessor` (só apoiador) |

## Onde colar

Supabase Dashboard → **Authentication** → **Email Templates** → **Invite user**.

### Assunto (Subject)

```
{{ if eq (index .Data "invite_kind") "assessor" }}Convite — assessor(a) da campanha{{ else if eq (index .Data "invite_kind") "apoiador" }}Convite — apoiador(a) da campanha{{ else }}Convite — CampanhaMT{{ end }}
```

### Corpo (Body) — HTML

```html
<h2>Olá, {{ index .Data "full_name" }}!</h2>

{{ if eq (index .Data "invite_kind") "assessor" }}
<p><strong>{{ index .Data "candidato_nome" }}</strong> convida você a integrar a <strong>equipe de assessores</strong> da campanha — um papel de confiança na organização e no acompanhamento do mandato.</p>
<p>Clique no botão abaixo para <strong>criar sua senha</strong> e acessar o <strong>CampanhaMT</strong> (mapa de votos, votantes, agenda e mensagens da campanha).</p>
{{ else if eq (index .Data "invite_kind") "apoiador" }}
<p><strong>{{ index .Data "candidato_nome" }}</strong> convida você a fazer parte da <strong>rede de apoiadores</strong>. No app você poderá cadastrar votantes, acompanhar o mapa e receber avisos da equipe.</p>
<p>{{ if eq (index .Data "convidante_papel") "assessor" }}Este convite foi enviado por <strong>{{ index .Data "convidante_nome" }}</strong> (assessor da campanha).{{ else }}Este convite foi enviado pela própria campanha.{{ end }}</p>
{{ else }}
<p>Você foi convidado a acessar o aplicativo da campanha. Use o link abaixo para criar sua senha.</p>
{{ end }}

<p><a href="{{ .ConfirmationURL }}" style="display:inline-block;padding:12px 20px;background:#2563eb;color:#fff;text-decoration:none;border-radius:8px;">Aceitar convite e criar senha</a></p>
<p style="font-size:13px;color:#555;">Ou copie e cole este endereço no navegador:<br/>{{ .ConfirmationURL }}</p>
<p style="font-size:12px;color:#888;">Se você não esperava este e-mail, pode ignorá-lo com segurança.</p>
<p style="font-size:12px;color:#888;">— CampanhaMT · Gestão eleitoral</p>
```

### Variante com ponto (se `index` der erro ao guardar)

Substitua no assunto e no corpo `{{ index .Data "invite_kind" }}` por `{{ .Data.invite_kind }}`, e o mesmo para `full_name`, `candidato_nome`, `convidante_nome`, `convidante_papel` (ex.: `{{ .Data.candidato_nome }}`). Guarde de novo; se o preview falhar, volte à versão com `index`.

## Remetente “Supabase Auth” → nome da campanha

Com o envio padrão do Supabase o remetente costuma ser fixo. Para aparecer **CampanhaMT** (ou outro nome) e melhorar entregabilidade:

**Project Settings → Authentication** (ou **Configure** do Auth) → **SMTP Settings**: configure um provedor (Resend, SendGrid, Amazon SES, etc.) e defina **Sender name** / **From** como `CampanhaMT` ou `Equipe — [Nome do candidato]`.

### Gmail (ex.: `eleicoes2026mt@gmail.com`)

Todos os campos têm de estar preenchidos; senão o banner “All fields must be filled” continua e **nenhum** e-mail sai por este SMTP.

| Campo | Valor típico |
|--------|----------------|
| **Host** | `smtp.gmail.com` |
| **Port** | `465` (SSL) ou `587` (STARTTLS — use o que o painel do Supabase pedir para o modo TLS) |
| **Username** | o e-mail completo, ex.: `eleicoes2026mt@gmail.com` |
| **Password** | **palavra-passe de aplicação** do Google (não a senha normal), se a conta tiver verificação em 2 passos: [Conta Google → Segurança → Palavras-passe de aplicação](https://myaccount.google.com/apppasswords) |

**Sender email address** no Supabase deve ser o **mesmo** Gmail (ou um alias autorizado nessa conta). Sem App Password, o Gmail bloqueia login SMTP.

Alternativas mais simples para campanha: [Resend](https://resend.com) ou SendGrid (domínio verificado + SMTP na documentação deles).

Depois de alterar os templates, faça deploy das funções que enviam convites (para enviarem os novos metadados):

`supabase functions deploy convidar-assessor convidar-apoiador reenviar-convite-assessor reenviar-convite-apoiador`
