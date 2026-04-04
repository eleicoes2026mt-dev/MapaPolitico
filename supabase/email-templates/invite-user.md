# E-mail de convite (Auth) — CampanhaMT

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

Se o editor do Supabase não aceitar `index .Data "chave"`, teste a variante `{{ .Data.invite_kind }}` / `{{ .Data.candidato_nome }}` (depende da versão do GoTrue).

## Remetente “Supabase Auth” → nome da campanha

Com o envio padrão do Supabase o remetente costuma ser fixo. Para aparecer **CampanhaMT** (ou outro nome) e melhorar entregabilidade:

**Project Settings → Authentication** (ou **Configure** do Auth) → **SMTP Settings**: configure um provedor (Resend, SendGrid, Amazon SES, etc.) e defina **Sender name** / **From** como `CampanhaMT` ou `Equipe — [Nome do candidato]`.

Depois de alterar os templates, faça deploy das funções que enviam convites (para enviarem os novos metadados):

`supabase functions deploy convidar-assessor convidar-apoiador reenviar-convite-assessor reenviar-convite-apoiador`
