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

## 3. Depois disto

- **`git push origin main`** → a Vercel inicia um deployment novo (vês na aba **Deployments** com origem **Git**, não só `vercel deploy`).

## 4. Deploy manual (como antes)

Se precisares sem esperar pelo Git:

```bash
vercel --prod
```

A pasta **`.vercel`** (link local) está no **`.gitignore`** — não vai para o GitHub; cada máquina pode ligar ao mesmo projeto com `vercel link`.

## 5. Variáveis de ambiente

**Settings** → **Environment Variables**: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `APP_URL`, etc., para **Production** (e Preview se quiseres).
