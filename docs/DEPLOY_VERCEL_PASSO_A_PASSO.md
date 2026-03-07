# Deploy na Vercel – Passo a passo

Flutter Web é compilado no **GitHub Actions** (porque a Vercel não tem Flutter). O resultado (`build/web`) é enviado para a Vercel. Siga na ordem.

---

## 1. Secrets no GitHub

Repositório: **eleicoes2026mt-dev/MapaPolitico** → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**.

Crie estes 5 secrets (nomes exatos):

| Secret             | Onde pegar |
|--------------------|------------|
| `SUPABASE_URL`     | Supabase → Project Settings → API → **Project URL** |
| `SUPABASE_ANON_KEY`| Supabase → Project Settings → API → **anon public** |
| `VERCEL_TOKEN`     | Vercel → Account Settings → **Tokens** → Create Token (ex.: nome `github-mapapolitico`) |
| `VERCEL_ORG_ID`    | Vercel → **Team** (ex.: eleicoes2026mt-3466) → **Settings** → **General** → **Team ID** |
| `VERCEL_PROJECT_ID`| Vercel → projeto **mapa-politico** → **Settings** → **General** → **Project ID** |

Sem esses 5, o workflow falha (build ou deploy).

---

## 2. Vercel: ignorar build automático

A Vercel não tem Flutter. Se ela tentar buildar sozinha no push, dá erro. Por isso desligamos o build dela.

1. Vercel → projeto **mapa-politico** → **Settings** → **General**.
2. Em **Build & Development**, ache **Ignored Build Step**.
3. Ative e no comando coloque: **`exit 0`**.
4. Salve.

Assim, push no GitHub **não** dispara build na Vercel; só a nossa Action faz o deploy.

---

## 3. O que a Action faz (resumo)

Cada **push na `main`** (ou **Run workflow** manual):

1. **Checkout** do repositório.
2. **Instalar Flutter** 3.24.0 (stable).
3. **Build:** `flutter pub get` e `flutter build web --release` com `SUPABASE_URL` e `SUPABASE_ANON_KEY`.
4. **Copiar** `vercel.json` para `build/web` (rewrites para SPA).
5. **Deploy** da pasta `build/web` na Vercel com `--prod`.

O **único** deploy que sobe o site é esse passo 5. A URL de produção sai no log do passo **"URL em produção"**.

---

## 4. Testar o build na sua máquina

Antes de confiar no CI, rode localmente (PowerShell na pasta do projeto):

```powershell
flutter pub get
flutter build web --release
```

Se der erro, corrija no código/dependências. O CI usa a mesma versão de Flutter (3.24.0); se quiser igualar, use `flutter version 3.24.0` e rode de novo.

---

## 5. Disparar o deploy

- **Automático:** dar push na branch `main`.
- **Manual:** GitHub → **Actions** → **Build e Deploy na Vercel** → **Run workflow** → **Run workflow**.

---

## 6. Onde ver a URL do site

1. GitHub → **Actions** → clique na run (ex.: último commit).
2. Abra o job **deploy**.
3. Clique no passo **"URL em produção"**.
4. No log aparece: `Site: https://mapa-politico-....vercel.app` (ou o domínio do projeto). Use esse link.

O dashboard da Vercel pode mostrar deploys "Canceled" ou "Error" (build dela ignorado ou falha). O que importa é o deploy feito pela Action; a URL está no log da Action.

---

## 7. Se algo falhar

- **"version solving failed" / intl:** o projeto não declara `intl`; vem do SDK. O workflow usa Flutter 3.24.0. Não adicione `intl` no `pubspec.yaml`.
- **"Process completed with exit code 1" no Build web:** abra o passo **Build web**, role até o fim do log e copie a mensagem de erro em vermelho (ex.: erro de compilação ou pacote).
- **"Process completed with exit code 1" no Deploy na Vercel:** confira os 5 secrets; em especial `VERCEL_TOKEN`, `VERCEL_ORG_ID` e `VERCEL_PROJECT_ID` do projeto **mapa-politico** e do time certo.
- **Nenhum deploy "Ready" na Vercel:** o site é publicado pelo passo **Deploy na Vercel** da Action. Use a URL que aparece no passo **"URL em produção"** do GitHub Actions.

---

## Resumo rápido

1. **5 secrets** no GitHub (Supabase + Vercel).
2. **Ignored Build Step** na Vercel = `exit 0`.
3. **Push na `main`** (ou Run workflow) → build no GitHub → deploy na Vercel.
4. **URL** → Actions → run → passo **"URL em produção"**.
