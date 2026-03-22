# Deploy: GitHub → Vercel (automático)

Hoje o projeto tem `vercel.json` na raiz (build Flutter Web). Para **cada push no `main` gerar deploy sozinho**:

## 1. Ligar o repositório no Vercel

1. Acede a [vercel.com](https://vercel.com) → projeto **mapa-politico** (ou o nome que tiveres).
2. **Settings** → **Git**.
3. Em **Connected Git Repository**:
   - Se estiver vazio: **Connect Git Repository** → escolhe **GitHub** → autoriza → seleciona **`eleicoes2026mt-dev/MapaPolitico`** (ou o repo certo).
   - **Production Branch**: `main`.
4. Guarda.

## 2. Confirmar build (uma vez)

- **Settings** → **General** → **Root Directory**: raiz do repo (vazio ou `.`).
- O Vercel deve usar o `vercel.json`:
  - `installCommand` / `buildCommand` / `outputDirectory` já definidos.

### Overrides no dashboard (muito importante)

Se **Build Command** ou **Output Directory** estiverem com **Override: ligado**, o Vercel **ignora** o `vercel.json` nesses campos.

1. **Settings** → **General** → **Build and Deployment** → **Build and Development Settings**.
2. Recomendado: **desliga o override** em:
   - **Build Command**
   - **Output Directory** (o repo já usa `build/web`)
   - **Install Command** (o repo usa `bash scripts/vercel-install.sh`, que instala o Flutter na pasta do projeto)
3. **Porquê:** o `install` corre num passo e o `build` noutro. O teu override `flutter pub get && flutter build web…` assume `flutter` no PATH global — **não existe** na Vercel; o SDK só aparece depois do `vercel-install.sh`. O `vercel-build.sh` faz `export PATH="$ROOT/flutter/bin:$PATH"` e passa `--dart-define=…` com as variáveis do painel (**SUPABASE_URL**, **SUPABASE_ANON_KEY**, **APP_URL**, **GOOGLE_MAPS_API_KEY**).

Se o log ainda mostra o comando antigo (`if [ -d flutter ]`…), há override ou commit antigo — confirma que o **override está desligado** e que fizeste push do `vercel.json` atual.

O script `scripts/vercel-install.sh` clona **`stable` sem `--depth 1`** para o SDK não ficar **0.0.0-unknown** (necessário para pacotes como `flutter_map`).

### Aviso amarelo “Configuration differs from Production”

Depois de mudares settings, faz um **Redeploy** para o ambiente de produção alinhar com o projeto.

## 3. Depois disto

- **`git push origin main`** → a Vercel inicia um deployment novo (vês na aba **Deployments** com origem **Git**, não só `vercel deploy`).

## 4. Deploy manual (como antes)

Se precisares sem esperar pelo Git:

```bash
vercel --prod
```

O build corre **nos servidores Linux da Vercel** (`scripts/vercel-install.sh` / `vercel-build.sh`).  
Se no **Windows** vires erro com `if [ -d flutter ]`, não uses PowerShell para esse comando: o problema era sintaxe Bash no sítio errado — o repo agora usa scripts `.sh` só na cloud.

A pasta **`.vercel`** (link local) está no **`.gitignore`** — não vai para o GitHub; cada máquina pode ligar ao mesmo projeto com `vercel link`.

## 5. Variáveis de ambiente

**Settings** → **Environment Variables**: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `APP_URL`, etc., para **Production** (e Preview se quiseres).
