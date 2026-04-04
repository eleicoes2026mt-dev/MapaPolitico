-- =============================================================================
-- EMERGÊNCIA / DEMO: forçar UM e-mail como único candidato na base
-- =============================================================================
-- Onde correr: Supabase Dashboard → SQL Editor → New query → Colar isto → Run
-- Requer permissão para ler auth.users (o editor do projeto tem).
--
-- O que faz:
-- 1) Acha o UUID em auth.users pelo e-mail
-- 2) Cria/atualiza a linha em public.profiles
-- 3) Rebaixa QUALQUER OUTRO candidato para votante (regra: só um candidato)
-- 4) Promove o e-mail alvo a candidato
-- 5) Garante linha em assessores (o candidato também é assessor da própria campanha)
--
-- Depois: no app, faz refresh na página (F5) ou logout/login.
-- =============================================================================

DO $$
DECLARE
  v_email text := 'eleicoes2026mt@gmail.com';
  v_uid   uuid;
BEGIN
  SELECT id INTO v_uid
  FROM auth.users
  WHERE lower(email) = lower(v_email)
  LIMIT 1;

  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Nenhum utilizador em auth.users com e-mail %', v_email;
  END IF;

  -- Perfil mínimo (igual ao trigger de signup)
  INSERT INTO public.profiles (id, full_name, email, role)
  SELECT
    u.id,
    COALESCE(
      NULLIF(btrim(u.raw_user_meta_data->>'full_name'), ''),
      NULLIF(btrim(u.raw_user_meta_data->>'name'), ''),
      split_part(u.email, '@', 1)
    ),
    u.email,
    'votante'::app_role
  FROM auth.users u
  WHERE u.id = v_uid
  ON CONFLICT (id) DO UPDATE SET
    email = COALESCE(EXCLUDED.email, profiles.email),
    full_name = COALESCE(
      NULLIF(btrim(profiles.full_name), ''),
      EXCLUDED.full_name
    );

  -- Só pode haver um candidato neste modelo de campanha
  UPDATE public.profiles
  SET role = 'votante'::app_role, updated_at = now()
  WHERE role = 'candidato'::app_role
    AND id <> v_uid;

  UPDATE public.profiles
  SET role = 'candidato'::app_role, updated_at = now()
  WHERE id = v_uid;

  IF NOT EXISTS (SELECT 1 FROM public.assessores WHERE profile_id = v_uid) THEN
    INSERT INTO public.assessores (profile_id, nome, email, telefone, municipio_id, ativo)
    SELECT
      p.id,
      COALESCE(NULLIF(btrim(p.full_name), ''), 'Candidato'),
      p.email,
      p.phone,
      NULL,
      true
    FROM public.profiles p
    WHERE p.id = v_uid;
  END IF;

  RAISE NOTICE 'OK: % (%) é agora o candidato.', v_email, v_uid;
END $$;
