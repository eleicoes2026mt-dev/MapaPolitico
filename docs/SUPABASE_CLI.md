# Configurar Supabase CLI (Windows)

O projeto já está preparado para usar o Supabase remoto (URL e anon key no `lib/main.dart`). Para usar a **CLI** e rodar `supabase db push` (aplicar migrations) e outros comandos, siga os passos abaixo.

## 1. Instalar o Supabase CLI

### Opção A: Scoop (recomendado no Windows)

Abra o **PowerShell** e execute:

```powershell
# Permitir scripts (se ainda não fez)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# Instalar Scoop (se não tiver)
iwr -useb get.scoop.sh | iex

# Adicionar o bucket do Supabase e instalar a CLI
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase

# Conferir
supabase --version
```

### Opção B: npm / npx

Se você tem **Node.js 20+** instalado:

```powershell
# Usar sem instalar globalmente (sempre com npx)
npx supabase --version

# Ou instalar globalmente (pode dar problema no Windows)
npm install -g supabase
```

Se usar `npx`, nos passos abaixo troque `supabase` por `npx supabase` (ex.: `npx supabase login`).

---

## 2. Login na conta Supabase

No terminal, na pasta do projeto ou em qualquer lugar:

```powershell
supabase login
```

Isso abre o navegador para você autorizar; o token fica salvo no seu usuário.

---

## 3. Vincular o projeto (link)

Na **raiz do projeto** (onde está a pasta `supabase`):

```powershell
cd c:\Users\fabia\OneDrive\Desktop\Flutter\MapaPolitico
supabase link --project-ref mjmqadpqcatwgskywisk
```

Quando pedir a **senha do banco**, use a senha do projeto que você definiu no [Dashboard do Supabase](https://supabase.com/dashboard) (Project Settings → Database → Database password). Se não quiser informar agora, pode deixar em branco; o link funciona, mas alguns comandos (como `db push`) vão pedir a senha depois.

---

## 4. Comandos úteis

| Comando | Descrição |
|--------|------------|
| `supabase db push` | Aplica as migrations locais (`supabase/migrations/`) no projeto remoto. **Use isso para aplicar a migration do storage de avatars.** |
| `supabase db pull` | Gera uma migration a partir do schema atual do banco remoto. |
| `supabase migration list` | Lista migrations (local vs remoto). |
| `supabase status` | Mostra status dos serviços (quando estiver rodando local com `supabase start`). |

### Aplicar as migrations (incluindo avatars)

Depois de `supabase link`:

```powershell
supabase db push
```

Isso aplica todas as migrations ainda não aplicadas no projeto **mjmqadpqcatwgskywisk**, incluindo a do bucket `avatars` e políticas RLS do storage.

---

## 5. Arquivos do CLI no projeto

- **`supabase/config.toml`** – Configuração do CLI (já criado para este projeto).
- **`supabase/migrations/`** – Migrations SQL; `db push` aplica essas pastas no banco remoto.
- **`.supabase/`** – Criado após `supabase link`; guarda o project ref (não versionar se tiver dados sensíveis).

O **project ref** usado no app e no link é: **mjmqadpqcatwgskywisk** (extraído da URL em `lib/main.dart`).
