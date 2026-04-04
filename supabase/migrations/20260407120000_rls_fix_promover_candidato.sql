-- Corrige promoção a candidato com RLS ativo: políticas "own" com WITH CHECK explícito
-- e RPC promover_candidato_se_vazio com bypass RLS na transação (SET row_security = off).

DROP POLICY IF EXISTS "profiles_own" ON public.profiles;
CREATE POLICY "profiles_own" ON public.profiles
  FOR ALL TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS "assessores_own" ON public.assessores;
CREATE POLICY "assessores_own" ON public.assessores
  FOR ALL TO authenticated
  USING (profile_id = auth.uid())
  WITH CHECK (profile_id = auth.uid());

CREATE OR REPLACE FUNCTION public.promover_candidato_se_vazio()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  uid uuid := auth.uid();
  existente uuid;
BEGIN
  IF uid IS NULL THEN
    RETURN jsonb_build_object('error', 'Não autorizado');
  END IF;

  PERFORM set_config('row_security', 'off', true);

  SELECT id INTO existente FROM public.profiles WHERE role = 'candidato' LIMIT 1;

  IF existente IS NOT NULL AND existente <> uid THEN
    RETURN jsonb_build_object(
      'error',
      'Já existe um Candidato cadastrado. Apenas ele pode convidar assessores.'
    );
  END IF;

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
  WHERE u.id = uid
  ON CONFLICT (id) DO UPDATE SET
    email = COALESCE(profiles.email, EXCLUDED.email),
    full_name = COALESCE(
      NULLIF(btrim(profiles.full_name), ''),
      EXCLUDED.full_name
    );

  UPDATE public.profiles
  SET role = 'candidato'::app_role, updated_at = now()
  WHERE id = uid;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'error',
      'Conta de autenticação não encontrada. Faça logout e entre novamente; se persistir, contate o suporte.'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.assessores WHERE profile_id = uid) THEN
    INSERT INTO public.assessores (profile_id, nome, email, telefone, municipio_id, ativo)
    SELECT
      p.id,
      COALESCE(NULLIF(btrim(p.full_name), ''), 'Candidato'),
      p.email,
      p.phone,
      NULL,
      true
    FROM public.profiles p
    WHERE p.id = uid;
  END IF;

  RETURN jsonb_build_object(
    'ok',
    true,
    'message',
    'Acesso Candidato ativado. Você já pode convidar assessores.'
  );
END;
$$;

COMMENT ON FUNCTION public.promover_candidato_se_vazio() IS
  'Promove a candidato; RLS desligado dentro da transação; cria perfil/assessor se faltar.';

GRANT EXECUTE ON FUNCTION public.promover_candidato_se_vazio() TO authenticated;
