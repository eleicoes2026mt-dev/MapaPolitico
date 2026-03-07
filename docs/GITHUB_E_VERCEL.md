# Subir o projeto no GitHub e configurar deploy na Vercel

O repositório Git já está inicializado na pasta do projeto, com commit inicial. Falta só criar o repositório no GitHub e enviar o código.

---

## 1. Criar o repositório no GitHub

1. Acesse **https://github.com** e faça login.
2. Clique em **+** (canto superior direito) → **New repository**.
3. Preencha:
   - **Repository name:** `MapaPolitico` ou `CampanhaMT` (o que preferir).
   - **Visibility:** Private ou Public.
   - **Não marque** "Add a README", "Add .gitignore" nem "Choose a license" (o projeto já tem).
4. Clique em **Create repository**.

---

## 2. Enviar o código para o GitHub

No PowerShell, na pasta do projeto:

```powershell
cd "c:\Users\fabia\OneDrive\Desktop\Flutter\MapaPolitico"
.\subir_github.ps1 -Usuario SEU_USUARIO -Repo NOME_DO_REPO
```

Troque:
- **SEU_USUARIO** pelo seu usuário do GitHub.
- **NOME_DO_REPO** pelo nome que você deu ao repositório (ex.: `MapaPolitico`).

**Exemplo:** se seu usuário for `fabiano` e o repo `MapaPolitico`:
```powershell
.\subir_github.ps1 -Usuario fabiano -Repo MapaPolitico
```

Quando o Git pedir **usuário e senha**, use:
- **Usuário:** seu usuário do GitHub.
- **Senha:** sua senha **ou** um **Personal Access Token** (recomendado se tiver 2FA).  
  Para criar um token: GitHub → Settings → Developer settings → Personal access tokens → Generate new token (marque pelo menos `repo`).

---

## 3. Conectar à Vercel e fazer deploy

1. Acesse **https://vercel.com** → **Add New** → **Project**.
2. Clique em **Continue with GitHub** e autorize a Vercel.
3. Na lista, escolha o repositório que você acabou de criar (ex.: `MapaPolitico`) e clique em **Import**.
4. Em **Configure Project**:
   - **Framework Preset:** Other.
   - **Build Command:**  
     `flutter pub get && flutter build web --release --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY`
   - **Output Directory:** `build/web`
   - **Install Command:** deixe em branco (ou use o que o template Flutter da Vercel indicar, se estiver usando um).
5. Em **Environment Variables**, adicione:
   - `SUPABASE_URL` = URL do seu projeto Supabase (ex.: `https://mjmqadpqcatwgskywisk.supabase.co`).
   - `SUPABASE_ANON_KEY` = chave anon do Supabase (Dashboard → Project Settings → API).
6. Clique em **Deploy**.

**Observação:** o ambiente de build da Vercel precisa ter o Flutter instalado. Se o deploy falhar por “flutter not found”, use um template ou imagem de build que inclua Flutter, ou faça o build local e faça deploy só da pasta `build/web` (veja [DEPLOY_VERCEL.md](DEPLOY_VERCEL.md)).

---

## 4. Deploy automático quando for preciso

Depois que o projeto estiver conectado à Vercel:

- **Cada push na branch `main`** (ex.: depois de `git add .` → `git commit -m "..."` → `git push`) dispara um novo deploy na Vercel.
- Você pode trabalhar normalmente no Cursor, fazer commit e push quando quiser; a Vercel publica a versão nova sozinha.

Resumo: **subir no GitHub** (passo 2) **e importar na Vercel** (passo 3) deixa tudo configurado para deploy sempre que você der push.
