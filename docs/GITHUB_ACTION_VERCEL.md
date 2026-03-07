# Deploy automático: GitHub Action + Vercel

A Vercel **não tem Flutter** nos servidores de build, por isso o comando `flutter build web` falha com "flutter: command not found".  
A solução é fazer o build no **GitHub Actions** (que tem Flutter) e enviar só a pasta `build/web` para a Vercel.

---

## 1. Ignorar o build na Vercel

Para o push no GitHub não disparar um build que vai falhar na Vercel:

1. Vercel → projeto **mapa-politico** → **Settings** → **General**.
2. Em **Build & Development**, role até **Ignored Build Step**.
3. Ative e use o comando: **`exit 0`** (ou **`true`**).  
   Assim a Vercel não executa o build; o deploy passa a ser feito só pela Action.

---

## 2. Secrets no GitHub

No repositório **eleicoes2026mt-dev/MapaPolitico**:

1. **Settings** → **Secrets and variables** → **Actions**.
2. Clique em **New repository secret** e crie:

| Nome | Onde pegar |
|------|------------|
| `SUPABASE_URL` | Supabase → Project Settings → API → Project URL (ex.: `https://mjmqadpqcatwgskywisk.supabase.co`) |
| `SUPABASE_ANON_KEY` | Supabase → Project Settings → API → anon public |
| `VERCEL_TOKEN` | Vercel → Account Settings → Tokens → Create Token (nome ex.: `github-mapapolitico`) |
| `VERCEL_ORG_ID` | Ver passo 3 abaixo |
| `VERCEL_PROJECT_ID` | Ver passo 3 abaixo |

---

## 3. Pegar VERCEL_ORG_ID e VERCEL_PROJECT_ID

**Opção A – Pelo projeto já linkado no PC**

Na pasta do projeto, se você já rodou `vercel link` em **build/web**:

- Abra **build/web/.vercel/project.json** (ou **.vercel/project.json** na raiz, se tiver).
- Use `orgId` como **VERCEL_ORG_ID** e `projectId` como **VERCEL_PROJECT_ID**.

**Opção B – Pelo dashboard da Vercel**

- **Project ID:** projeto **mapa-politico** → **Settings** → **General** → **Project ID** (copie).
- **Team/Org ID:** **Team Settings** → **General** → **Team ID** (copie e use como **VERCEL_ORG_ID**).

Crie os secrets **VERCEL_ORG_ID** e **VERCEL_PROJECT_ID** com esses valores.

---

## 4. O que a Action faz

- Em cada **push na branch main** (e no **Run workflow** manual):
  1. Faz checkout do repositório.
  2. Instala o Flutter e roda `flutter pub get` e `flutter build web --release` com `SUPABASE_URL` e `SUPABASE_ANON_KEY`.
  3. Copia **vercel.json** para **build/web** (para as rewrites do Flutter Web).
  4. Faz deploy de **build/web** na Vercel com `--prod`.

Assim o build roda no GitHub (com Flutter) e a Vercel só recebe os arquivos estáticos; não precisa de Flutter na Vercel.

---

## 5. Depois de configurar

1. Salve os secrets no GitHub.
2. Configure o **Ignored Build Step** na Vercel (passo 1).
3. Dê um **push** na **main** ou rode o workflow em **Actions** → **Build e Deploy na Vercel** → **Run workflow**.

O deploy deve concluir e o site ficar em **https://mapa-politico-....vercel.app** (ou no domínio que você configurou).

---

## 6. Verificar o site em produção

1. **Abrir o URL do projeto**
   - Vercel → **Dashboard** → projeto **mapa-politico** → aba **Deployments**.
   - No último deploy com status **Ready**, clique em **Visit** (ou no domínio exibido).
   - Ou use o domínio que você configurou (ex.: `mapa-politico.vercel.app` ou domínio customizado).

2. **Checklist rápido**
   - [ ] A página inicial carrega (tela de login ou home do CampanhaMT).
   - [ ] Ao recarregar em uma rota (ex.: `/perfil` ou `/assessores`), não aparece 404 (graças ao `vercel.json`).
   - [ ] Login com Supabase funciona (as variáveis `SUPABASE_URL` e `SUPABASE_ANON_KEY` foram usadas no build).
   - [ ] Navegação entre telas e dados do Supabase respondem normalmente.

Se algo falhar (ex.: tela em branco ou erro de rede), confira no navegador **F12 → Console** e, na Vercel, **Deployments → último deploy → Function Logs / Build Logs** (se aplicável).

---

## 7. Nenhum deploy com status "Ready"

Se na Vercel todos os deploys aparecem como **Error** ou **Canceled**:

1. **Quem realmente publica o site é a GitHub Action**  
   O deploy que sobe o `build/web` é o passo **"Deploy na Vercel"** da Action. A URL de produção sai no log da Action, no passo **"URL do deploy"** (ex.: `https://mapa-politico-xxx.vercel.app`). Use essa URL para abrir o site, mesmo que no dashboard não apareça um deploy "Ready".

2. **Confirme o Ignored Build Step**  
   Vercel → **mapa-politico** → **Settings** → **General** → **Ignored Build Step** = **`exit 0`**.  
   Assim o push no Git não dispara um build na Vercel (que falharia em 4s sem Flutter). Os deploys "Error" em 4s costumam ser esse build automático falhando.

3. **Confirme os secrets do projeto certo**  
   **VERCEL_ORG_ID** e **VERCEL_PROJECT_ID** no GitHub devem ser do projeto **mapa-politico** onde você quer o site (Settings → General do projeto e do time). Se forem de outro projeto, o site vai para o lugar errado e o mapa-politico pode nunca ficar "Ready".

4. **Rode a Action de novo e pegue a URL**  
   GitHub → **Actions** → **Build e Deploy na Vercel** → **Run workflow** → espere terminar → abra a run → no passo **"URL do deploy"** aparece o link de produção. Abra esse link para testar o site.
