# E-mail de convite (assessores) – Supabase

Para o link do convite **não** aparecer como localhost e a mensagem ficar em português e mais clara, configure o Supabase assim:

## 1. URL do site (obrigatório)

No **Supabase Dashboard** do projeto:

1. Vá em **Authentication** → **URL Configuration**.
2. Em **Site URL**, coloque a URL pública do app, por exemplo:
   - `https://web-liart-iota-22.vercel.app`
3. Em **Redirect URLs**, inclua a mesma URL (e outras que você usar), por exemplo:
   - `https://web-liart-iota-22.vercel.app/**`

Assim o texto do e-mail deixa de mostrar “localhost” e passa a mostrar a URL correta do app.

## 2. Template do e-mail de convite (opcional)

Para personalizar o texto do e-mail de convite:

1. No Dashboard: **Authentication** → **Email Templates**.
2. Selecione **Invite**.
3. Substitua o conteúdo pelo template abaixo (ou ajuste o texto como quiser).

**Assunto sugerido:**  
`Você foi convidado – CampanhaMT`

**Corpo (HTML):**

```html
<h2>Você foi convidado</h2>
<p>Olá,</p>
<p>Você foi convidado a participar do <strong>CampanhaMT – Gestão Eleitoral</strong> como assessor(a).</p>
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
