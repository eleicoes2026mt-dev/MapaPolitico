-- Ativar sync Supabase → Google Sheets (Apps Script)
-- Execute no SQL Editor do Supabase após supabase db push

UPDATE public.planilha_sync_config SET
  sync_enabled = true,
  webhook_secret = 'MinhaCampanha2026',
  apps_script_webapp_url = 'https://script.google.com/macros/s/AKfycbyH3gW84CgGud5etgMjdKGdHiM6JH5tAsVa3ada52cRA5Vnc6eTPqb69Q2gGqy6mAFK/exec',
  supabase_functions_url = NULL,
  updated_at = now()
WHERE id = 1;

SELECT public.planilha_sync_status();
