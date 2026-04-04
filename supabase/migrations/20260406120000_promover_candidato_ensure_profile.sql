-- Se não existir linha em public.profiles (trigger de signup falhou ou conta antiga),
-- promover_candidato_se_vazio devolvia "Perfil não encontrado". Passamos a criar o perfil
-- a partir de auth.users antes do UPDATE para candidato.

CREATE OR REPLACE FUNCTION public.promover_candidato_se_vazio()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid uuid := auth.uid();
  existente uuid;
BEGIN
  IF uid IS NULL THEN
    RETURN jsonb_build_object('error', 'Não autorizado');
  END IF;

  SELECT id INTO existente FROM profiles WHERE role = 'candidato' LIMIT 1;

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

  UPDATE profiles
  SET role = 'candidato'::app_role, updated_at = now()
  WHERE id = uid;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'error',
      'Conta de autenticação não encontrada. Faça logout e entre novamente; se persistir, contate o suporte.'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM assessores WHERE profile_id = uid) THEN
    INSERT INTO assessores (profile_id, nome, email, telefone, municipio_id, ativo)
    SELECT
      p.id,
      COALESCE(NULLIF(btrim(p.full_name), ''), 'Candidato'),
      p.email,
      p.phone,
      NULL,
      true
    FROM profiles p
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
  'Promove o usuário autenticado a candidato se não houver outro; cria profiles a partir de auth.users se faltar; cria assessores se faltar.';
