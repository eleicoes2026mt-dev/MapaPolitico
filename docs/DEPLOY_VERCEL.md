# Deploy Flutter Web na Vercel (CampanhaMT + Supabase)

Este guia explica como publicar o CampanhaMT na Vercel com as variáveis de ambiente do Supabase, para que a comunicação com o banco em produção funcione sem chaves no código.

---

## 1. Arquivos já configurados no projeto

- **`vercel.json`** – Rewrites para que todas as rotas (`/`, `/assessores`, `/perfil`, etc.) sirvam `index.html` e o Flutter Web não retorne 404 ao atualizar a página.
- **`lib/core/config/env_config.dart`** – Centraliza `SUPABASE_URL` e `SUPABASE_ANON_KEY` via `String.fromEnvironment` (usado no `main.dart`).
- **`build_vercel.sh`** – Script que roda `flutter build web --release` passando as variáveis com `--dart-define`.

---

## 2. Variáveis de ambiente no painel da Vercel

1. Acesse o projeto na **Vercel**.
2. Vá em **Settings** → **Environment Variables**.
3. Adicione:

   | Nome             | Valor                                                                 | Ambiente   |
   |------------------|-----------------------------------------------------------------------|------------|
   | `SUPABASE_URL`   | URL do seu projeto (ex.: `https://mjmqadpqcatwgskywisk.supabase.co`) | Production (e Preview se quiser) |
   | `SUPABASE_ANON_KEY` | Chave **anon** (pública) do Supabase (Dashboard → Project Settings → API) | Production (e Preview se quiser) |

4. Salve. Essas variáveis serão usadas no **Build Command** no próximo passo.

Assim as chaves não ficam no código e o app em produção usa o Supabase correto (ex.: dados de Mato Grosso).

---

## 3. Build e Output na Vercel

- **Framework Preset:** se não houver “Flutter”, escolha **Other**.
- **Build Command:** use um dos dois:

  **Opção A – Script (recomendado):**
  ```bash
  chmod +x build_vercel.sh && ./build_vercel.sh
  ```

  **Opção B – Comando direto:**
  ```bash
  flutter pub get && flutter build web --release --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
  ```

- **Output Directory:** `build/web`  
  (é onde o `flutter build web` gera os arquivos estáticos.)

- **Install Command:** deixe em branco ou, se o ambiente exigir instalação de dependências antes do Flutter, use o que a documentação do seu ambiente (ex.: template Flutter na Vercel) indicar.

**Importante:** O ambiente de build da Vercel precisa ter o **Flutter SDK** instalado. Se o projeto usar um template ou Docker image com Flutter, o comando acima funciona. Caso a Vercel não tenha Flutter no ambiente padrão, você pode:
- usar um **template Vercel + Flutter** da comunidade, ou
- fazer o build localmente (veja seção 4) e fazer deploy apenas da pasta `build/web`.

---

## 4. Build local (alternativa)

Se preferir gerar o build no seu PC e só enviar os arquivos estáticos:

```bash
export SUPABASE_URL="https://mjmqadpqcatwgskywisk.supabase.co"
export SUPABASE_ANON_KEY="sua-chave-anon-aqui"
./build_vercel.sh
```

Depois, na Vercel, aponte o **Output Directory** para `build/web` e use um Build Command que não rode Flutter (por exemplo, `echo "Build feito localmente"` ou um comando que só copie arquivos), ou faça deploy manual da pasta `build/web`.

---

## 5. Resumo

- **Segurança:** as chaves ficam só nas Environment Variables da Vercel, não no repositório.
- **Rotas:** o `vercel.json` evita 404 ao recarregar em qualquer rota do app.
- **Produção:** com `SUPABASE_URL` e `SUPABASE_ANON_KEY` configuradas na Vercel, o app em produção usa o mesmo Supabase (ex.: MT) e as edge networks da Vercel ajudam no carregamento em regiões como o interior de Mato Grosso.

Para dúvidas sobre onde achar a URL e a anon key no Supabase: **Dashboard do Supabase** → **Project Settings** → **API** (Project URL e anon/public key).
