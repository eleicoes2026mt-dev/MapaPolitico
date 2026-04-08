-- =============================================================================
-- Vincular TODOS os assessores ao candidato (por e-mail)
-- =============================================================================
-- Cenário: toda a equipe é assessora do mesmo deputado/candidato
-- (ex.: eleicoes2026mt@gmail.com). Cada linha em profiles com role = assessor
-- deve ter invited_by = UUID do perfil do candidato — é assim que o app resolve
-- dados da campanha (dashboard TSE, mapa, metas, etc.).
--
-- Onde correr: Supabase Dashboard → SQL Editor (role postgres / bypass RLS).
-- Depois: F5 no app ou logout/login nos utilizadores afetados.
-- =============================================================================

DO $$
DECLARE
  v_email     text := 'eleicoes2026mt@gmail.com';
  v_candidato uuid;
  n           int;
BEGIN
  SELECT p.id
  INTO v_candidato
  FROM public.profiles p
  WHERE lower(p.email) = lower(v_email)
    AND p.role = 'candidato'::public.app_role
  LIMIT 1;

  IF v_candidato IS NULL THEN
    RAISE EXCEPTION
      'Nenhum perfil com role = candidato e e-mail %. '
      'Execute antes force_candidato_por_email.sql ou promova o utilizador.',
      v_email;
  END IF;

  UPDATE public.profiles
  SET
    invited_by = v_candidato,
    updated_at = now()
  WHERE role = 'assessor'::public.app_role
    AND id <> v_candidato;

  GET DIAGNOSTICS n = ROW_COUNT;

  RAISE NOTICE 'Candidato (raiz): % — %', v_email, v_candidato;
  RAISE NOTICE 'Perfis assessor atualizados (invited_by): %', n;
END $$;

-- Conferência rápida
SELECT
  p.id,
  p.email,
  p.full_name,
  p.role,
  p.invited_by,
  (SELECT email FROM public.profiles c WHERE c.id = p.invited_by) AS email_candidato_invited_by
FROM public.profiles p
WHERE p.role = 'assessor'::public.app_role
ORDER BY p.email;
