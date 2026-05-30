-- Sincronização automática Supabase → Google Sheets (via Edge Function sync-contatos-planilha).
-- Após deploy, configure planilha_sync_config e secrets no Supabase (ver supabase/scripts/setup_planilha_google_sheets.sql).

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

CREATE TABLE IF NOT EXISTS public.planilha_sync_config (
  id int PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  sync_enabled boolean NOT NULL DEFAULT false,
  webhook_secret text,
  supabase_functions_url text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.planilha_sync_config IS
  'Liga triggers Postgres à Edge Function sync-contatos-planilha. Preencha supabase_functions_url e webhook_secret (igual PLANILHA_SYNC_SECRET).';

ALTER TABLE public.planilha_sync_config ENABLE ROW LEVEL SECURITY;

INSERT INTO public.planilha_sync_config (id, sync_enabled)
VALUES (1, false)
ON CONFLICT (id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.trg_planilha_sync_contato()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  cfg record;
  v_tipo text;
  v_url text;
  v_secret text;
BEGIN
  SELECT sync_enabled, webhook_secret, supabase_functions_url
  INTO cfg
  FROM public.planilha_sync_config
  WHERE id = 1;

  IF NOT COALESCE(cfg.sync_enabled, false) THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  v_url := nullif(trim(cfg.supabase_functions_url), '');
  v_secret := nullif(trim(cfg.webhook_secret), '');
  IF v_url IS NULL OR v_secret IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  v_tipo := TG_TABLE_NAME;
  IF v_tipo NOT IN ('apoiadores', 'votantes', 'assessores') THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  -- Apoiador soft-deleted: não envia linha nova (sync completo limpa depois).
  IF TG_TABLE_NAME = 'apoiadores' AND TG_OP = 'UPDATE' AND NEW.excluido_em IS NOT NULL THEN
    RETURN NEW;
  END IF;

  BEGIN
    PERFORM net.http_post(
      url := v_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'X-Planilha-Sync-Secret', v_secret
      ),
      body := jsonb_build_object(
        'modo', 'registro',
        'tipo', CASE v_tipo
          WHEN 'apoiadores' THEN 'apoiador'
          WHEN 'votantes' THEN 'votante'
          WHEN 'assessores' THEN 'assessor'
        END,
        'id', (COALESCE(NEW, OLD)).id::text
      )
    );
  EXCEPTION
    WHEN OTHERS THEN
      RAISE WARNING 'planilha_sync falhou (%): %', v_tipo, SQLERRM;
  END;

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS planilha_sync_apoiadores ON public.apoiadores;
CREATE TRIGGER planilha_sync_apoiadores
  AFTER INSERT OR UPDATE ON public.apoiadores
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_planilha_sync_contato();

DROP TRIGGER IF EXISTS planilha_sync_votantes ON public.votantes;
CREATE TRIGGER planilha_sync_votantes
  AFTER INSERT OR UPDATE ON public.votantes
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_planilha_sync_contato();

DROP TRIGGER IF EXISTS planilha_sync_assessores ON public.assessores;
CREATE TRIGGER planilha_sync_assessores
  AFTER INSERT OR UPDATE ON public.assessores
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_planilha_sync_contato();

-- RPC: gestor dispara sync completa (chama a Edge Function com JWT do cliente).
CREATE OR REPLACE FUNCTION public.planilha_sync_status()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'sync_enabled', COALESCE(c.sync_enabled, false),
    'functions_url_configured', nullif(trim(c.supabase_functions_url), '') IS NOT NULL,
    'secret_configured', nullif(trim(c.webhook_secret), '') IS NOT NULL,
    'updated_at', c.updated_at
  )
  FROM public.planilha_sync_config c
  WHERE c.id = 1;
$$;

GRANT EXECUTE ON FUNCTION public.planilha_sync_status() TO authenticated;

COMMENT ON FUNCTION public.trg_planilha_sync_contato() IS
  'POST assíncrono para sync-contatos-planilha quando planilha_sync_config.sync_enabled = true.';
