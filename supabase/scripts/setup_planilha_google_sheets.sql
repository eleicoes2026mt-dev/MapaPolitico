-- ═══════════════════════════════════════════════════════════════════════════════
-- Setup: Google Sheets ↔ Supabase (CampanhaMT)
-- Planilha: base_mandato_deputado_gilberto_figueiredo
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- PASSO 1 — Google Cloud (console.cloud.google.com)
--   • Crie um projeto (ou use um existente).
--   • Ative a API «Google Sheets API».
--   • IAM → Contas de serviço → Criar → baixe o JSON da chave.
--   • Copie client_email e private_key do JSON.
--
-- PASSO 2 — Compartilhar a planilha
--   • Abra a planilha no Google Sheets.
--   • Compartilhar → adicione o e-mail da conta de serviço (…@….iam.gserviceaccount.com)
--     com permissão «Editor».
--   • Copie o ID da URL:
--     https://docs.google.com/spreadsheets/d/ESTE_ID_AQUI/edit
--
-- PASSO 3 — Cabeçalho na linha 1 (colunas A–R)
--   Id | Nome Completo * | Nº WhatsApp * | Município * | Bairro / Região | Lugar |
--   Faixa de Idade | Tipo de Contato * | Engajamento * | Segmento de Atuação |
--   Pauta de Interesse | Orientação Política | Canal de Origem * | Data de Entrada * |
--   Último Contato | Grupos | Observações | Status *
--
-- PASSO 4 — Secrets no Supabase (Dashboard → Edge Functions → Secrets)
--   GOOGLE_SHEETS_SPREADSHEET_ID = (ID da planilha)
--   GOOGLE_SHEETS_SHEET_NAME     = Página1   (nome da aba)
--   GOOGLE_SERVICE_ACCOUNT_EMAIL = client_email do JSON
--   GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY = private_key (com \n nas quebras)
--   PLANILHA_SYNC_SECRET         = escolha uma senha longa aleatória
--
-- PASSO 5 — Deploy da função
--   supabase functions deploy sync-contatos-planilha --no-verify-jwt
--
-- PASSO 6 — Ativar triggers (SQL Editor no Supabase)
--   Substitua os valores abaixo e execute:

UPDATE public.planilha_sync_config
SET
  sync_enabled = true,
  webhook_secret = 'COLOQUE_A_MESMA_SENHA_DO_PLANILHA_SYNC_SECRET',
  supabase_functions_url = 'https://SEU_PROJECT_REF.supabase.co/functions/v1/sync-contatos-planilha',
  updated_at = now()
WHERE id = 1;

-- PASSO 7 — Carga inicial (sync completa)
--   No app, entre como candidato ou assessor grau 1 e chame a função, OU use curl:
--
-- curl -X POST 'https://SEU_PROJECT_REF.supabase.co/functions/v1/sync-contatos-planilha' \
--   -H 'Authorization: Bearer SEU_JWT' \
--   -H 'Content-Type: application/json' \
--   -d '{"modo":"completo"}'
--
-- A partir daí, cada INSERT/UPDATE em apoiadores, votantes ou assessores
-- envia automaticamente uma linha (ou atualiza se o Id já existir na coluna A).
--
-- Coluna A (Id) usa o formato: apoiador:uuid | votante:uuid | assessor:uuid

SELECT public.planilha_sync_status();
