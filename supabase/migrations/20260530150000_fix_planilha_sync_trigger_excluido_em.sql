-- Corrige trigger planilha: NEW.excluido_em só existe em apoiadores.
-- Sem isso, INSERT/UPDATE em votantes e assessores falham com erro 42703.

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
  v_body jsonb;
  v_headers jsonb;
BEGIN
  SELECT sync_enabled, webhook_secret, supabase_functions_url, apps_script_webapp_url
  INTO cfg
  FROM public.planilha_sync_config
  WHERE id = 1;

  IF NOT COALESCE(cfg.sync_enabled, false) THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  v_secret := nullif(trim(cfg.webhook_secret), '');
  IF v_secret IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  IF nullif(trim(cfg.apps_script_webapp_url), '') IS NOT NULL THEN
    v_url := trim(cfg.apps_script_webapp_url);
  ELSE
    v_url := nullif(trim(cfg.supabase_functions_url), '');
  END IF;

  IF v_url IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  v_tipo := TG_TABLE_NAME;
  IF v_tipo NOT IN ('apoiadores', 'votantes', 'assessores') THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  IF TG_TABLE_NAME = 'apoiadores' AND TG_OP = 'UPDATE'
     AND (to_jsonb(NEW)->>'excluido_em') IS NOT NULL THEN
    RETURN NEW;
  END IF;

  v_body := jsonb_build_object(
    'secret', v_secret,
    'modo', 'registro',
    'tipo', CASE v_tipo
      WHEN 'apoiadores' THEN 'apoiador'
      WHEN 'votantes' THEN 'votante'
      WHEN 'assessores' THEN 'assessor'
    END,
    'id', (COALESCE(NEW, OLD)).id::text
  );

  IF nullif(trim(cfg.apps_script_webapp_url), '') IS NOT NULL THEN
    v_headers := jsonb_build_object('Content-Type', 'application/json');
  ELSE
    v_headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'X-Planilha-Sync-Secret', v_secret
    );
    v_body := v_body - 'secret';
  END IF;

  BEGIN
    PERFORM net.http_post(
      url := v_url,
      headers := v_headers,
      body := v_body
    );
  EXCEPTION
    WHEN OTHERS THEN
      RAISE WARNING 'planilha_sync falhou (%): %', v_tipo, SQLERRM;
  END;

  RETURN COALESCE(NEW, OLD);
END;
$$;
