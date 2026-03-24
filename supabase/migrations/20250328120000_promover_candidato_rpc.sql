-- Promoção a candidato via RPC (não depende da Edge Function estar deployada).
-- Mesma regra da função Deno: só um candidato; se já existir outro, retorna erro em JSON.

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

  UPDATE profiles
  SET role = 'candidato'::app_role, updated_at = now()
  WHERE id = uid;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Perfil não encontrado');
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
  'Promove o usuário autenticado a candidato se não houver outro candidato; cria linha em assessores se faltar.';

GRANT EXECUTE ON FUNCTION public.promover_candidato_se_vazio() TO authenticated;
