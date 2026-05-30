-- =============================================================================
-- INSTALAÇÃO COMPLETA: sync Supabase → Google Sheets (Apps Script)
-- Cole TUDO no SQL Editor do Supabase e clique Run (uma vez só).
-- =============================================================================

-- --- Migração 20260530120000 ---
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

CREATE TABLE IF NOT EXISTS public.planilha_sync_config (
  id int PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  sync_enabled boolean NOT NULL DEFAULT false,
  webhook_secret text,
  supabase_functions_url text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.planilha_sync_config IS
  'Liga triggers Postgres ao Apps Script ou Edge Function de sync com planilha.';

ALTER TABLE public.planilha_sync_config ENABLE ROW LEVEL SECURITY;

INSERT INTO public.planilha_sync_config (id, sync_enabled)
VALUES (1, false)
ON CONFLICT (id) DO NOTHING;

-- --- Migração 20260530140000 (Apps Script) ---
ALTER TABLE public.planilha_sync_config
  ADD COLUMN IF NOT EXISTS apps_script_webapp_url text;

CREATE OR REPLACE FUNCTION public._planilha_validar_secret(p_secret text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT nullif(trim(p_secret), '') IS NOT NULL
    AND nullif(trim(p_secret), '') = (
      SELECT nullif(trim(webhook_secret), '')
      FROM public.planilha_sync_config
      WHERE id = 1
    );
$$;

CREATE OR REPLACE FUNCTION public.planilha_export_contatos(p_secret text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_out jsonb;
BEGIN
  IF NOT public._planilha_validar_secret(p_secret) THEN
    RAISE EXCEPTION 'Secret inválido';
  END IF;

  SELECT COALESCE(jsonb_agg(r ORDER BY r->>'nome'), '[]'::jsonb)
  INTO v_out
  FROM (
    SELECT jsonb_build_object(
      'tipo', 'apoiador',
      'id', a.id,
      'nome', a.nome,
      'telefone', COALESCE(a.telefone, a.contato_responsavel),
      'municipio', COALESCE(m.nome, a.cidade_nome),
      'bairro', a.complemento,
      'lugar', ol.nome,
      'data_nascimento', a.data_nascimento,
      'perfil', a.perfil,
      'tipo_pessoa', a.tipo,
      'email', a.email,
      'link_instagram', a.link_instagram,
      'logradouro', a.logradouro,
      'numero', a.numero,
      'complemento_end', a.complemento,
      'estimativa_votos', a.estimativa_votos,
      'ativo', a.ativo,
      'excluido_em', a.excluido_em,
      'created_at', a.created_at,
      'updated_at', a.updated_at
    ) AS r
    FROM public.apoiadores a
    LEFT JOIN public.municipios m ON m.id = a.municipio_id
    LEFT JOIN public.apoiador_origem_lugares ol ON ol.id = a.origem_lugar_id
    WHERE a.excluido_em IS NULL

    UNION ALL

    SELECT jsonb_build_object(
      'tipo', 'votante',
      'id', v.id,
      'nome', v.nome,
      'telefone', v.telefone,
      'municipio', COALESCE(m.nome, v.cidade_nome),
      'bairro', v.complemento,
      'lugar', NULL,
      'data_nascimento', NULL,
      'perfil', NULL,
      'abrangencia', v.abrangencia,
      'qtd_votos_familia', v.qtd_votos_familia,
      'cadastro_via_qr', v.cadastro_via_qr,
      'cadastrado_pelo_candidato', v.cadastrado_pelo_candidato,
      'convite_por_nome', v.convite_por_nome,
      'email', v.email,
      'link_instagram', v.link_instagram,
      'logradouro', v.logradouro,
      'numero', v.numero,
      'created_at', v.created_at,
      'updated_at', v.updated_at
    )
    FROM public.votantes v
    LEFT JOIN public.municipios m ON m.id = v.municipio_id

    UNION ALL

    SELECT jsonb_build_object(
      'tipo', 'assessor',
      'id', s.id,
      'nome', s.nome,
      'telefone', s.telefone,
      'municipio', m.nome,
      'bairro', s.complemento,
      'lugar', NULL,
      'grau_acesso', s.grau_acesso,
      'email', s.email,
      'link_instagram', s.link_instagram,
      'logradouro', s.logradouro,
      'numero', s.numero,
      'ativo', s.ativo,
      'created_at', s.created_at,
      'updated_at', s.updated_at
    )
    FROM public.assessores s
    LEFT JOIN public.municipios m ON m.id = s.municipio_id
    LEFT JOIN public.profiles p ON p.id = s.profile_id
    WHERE COALESCE(p.role::text, '') <> 'candidato'
  ) q;

  RETURN jsonb_build_object('ok', true, 'records', v_out);
END;
$$;

CREATE OR REPLACE FUNCTION public.planilha_export_contato(
  p_secret text,
  p_tipo text,
  p_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rec jsonb;
  v_tipo text := lower(trim(p_tipo));
BEGIN
  IF NOT public._planilha_validar_secret(p_secret) THEN
    RAISE EXCEPTION 'Secret inválido';
  END IF;

  IF v_tipo = 'apoiador' THEN
    SELECT jsonb_build_object(
      'tipo', 'apoiador',
      'id', a.id,
      'nome', a.nome,
      'telefone', COALESCE(a.telefone, a.contato_responsavel),
      'municipio', COALESCE(m.nome, a.cidade_nome),
      'bairro', a.complemento,
      'lugar', ol.nome,
      'data_nascimento', a.data_nascimento,
      'perfil', a.perfil,
      'tipo_pessoa', a.tipo,
      'email', a.email,
      'link_instagram', a.link_instagram,
      'logradouro', a.logradouro,
      'numero', a.numero,
      'complemento_end', a.complemento,
      'estimativa_votos', a.estimativa_votos,
      'ativo', a.ativo,
      'excluido_em', a.excluido_em,
      'created_at', a.created_at,
      'updated_at', a.updated_at
    ) INTO v_rec
    FROM public.apoiadores a
    LEFT JOIN public.municipios m ON m.id = a.municipio_id
    LEFT JOIN public.apoiador_origem_lugares ol ON ol.id = a.origem_lugar_id
    WHERE a.id = p_id AND a.excluido_em IS NULL;
  ELSIF v_tipo = 'votante' THEN
    SELECT jsonb_build_object(
      'tipo', 'votante',
      'id', v.id,
      'nome', v.nome,
      'telefone', v.telefone,
      'municipio', COALESCE(m.nome, v.cidade_nome),
      'bairro', v.complemento,
      'abrangencia', v.abrangencia,
      'qtd_votos_familia', v.qtd_votos_familia,
      'cadastro_via_qr', v.cadastro_via_qr,
      'cadastrado_pelo_candidato', v.cadastrado_pelo_candidato,
      'convite_por_nome', v.convite_por_nome,
      'email', v.email,
      'link_instagram', v.link_instagram,
      'logradouro', v.logradouro,
      'numero', v.numero,
      'created_at', v.created_at,
      'updated_at', v.updated_at
    ) INTO v_rec
    FROM public.votantes v
    LEFT JOIN public.municipios m ON m.id = v.municipio_id
    WHERE v.id = p_id;
  ELSIF v_tipo = 'assessor' THEN
    SELECT jsonb_build_object(
      'tipo', 'assessor',
      'id', s.id,
      'nome', s.nome,
      'telefone', s.telefone,
      'municipio', m.nome,
      'bairro', s.complemento,
      'grau_acesso', s.grau_acesso,
      'email', s.email,
      'link_instagram', s.link_instagram,
      'logradouro', s.logradouro,
      'numero', s.numero,
      'ativo', s.ativo,
      'created_at', s.created_at,
      'updated_at', s.updated_at
    ) INTO v_rec
    FROM public.assessores s
    LEFT JOIN public.municipios m ON m.id = s.municipio_id
    WHERE s.id = p_id;
  ELSE
    RAISE EXCEPTION 'tipo inválido';
  END IF;

  IF v_rec IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'record', NULL);
  END IF;

  RETURN jsonb_build_object('ok', true, 'record', v_rec);
END;
$$;

REVOKE ALL ON FUNCTION public.planilha_export_contatos(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.planilha_export_contato(text, text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.planilha_export_contatos(text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.planilha_export_contato(text, text, uuid) TO anon, authenticated, service_role;

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
    'apps_script_url_configured', nullif(trim(c.apps_script_webapp_url), '') IS NOT NULL,
    'secret_configured', nullif(trim(c.webhook_secret), '') IS NOT NULL,
    'updated_at', c.updated_at
  )
  FROM public.planilha_sync_config c
  WHERE c.id = 1;
$$;

GRANT EXECUTE ON FUNCTION public.planilha_sync_status() TO authenticated;

-- --- Ativar com sua URL e senha ---
UPDATE public.planilha_sync_config SET
  sync_enabled = true,
  webhook_secret = 'MinhaCampanha2026',
  apps_script_webapp_url = 'https://script.google.com/macros/s/AKfycbyH3gW84CgGud5etgMjdKGdHiM6JH5tAsVa3ada52cRA5Vnc6eTPqb69Q2gGqy6mAFK/exec',
  supabase_functions_url = NULL,
  updated_at = now()
WHERE id = 1;

SELECT public.planilha_sync_status();
