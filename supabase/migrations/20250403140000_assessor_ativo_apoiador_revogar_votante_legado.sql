-- Votante: promessa na última eleição (legado)
ALTER TABLE votantes ADD COLUMN IF NOT EXISTS votos_prometidos_ultima_eleicao INTEGER;

COMMENT ON COLUMN votantes.votos_prometidos_ultima_eleicao IS 'Votos prometidos pelo votante na última eleição (referência histórica).';

-- Acesso: assessor/apoiador inativos ou perfil desativado não enxergam dados da campanha.
-- Nota Supabase hosted: a role de `db push` não tem permissão em `auth.*`; estes helpers ficam em `public`.
-- As policies antigas continuam a chamar `auth.my_*` onde já existem; novas RPCs usam `public.app_*`.

CREATE OR REPLACE FUNCTION public.app_is_candidato()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
      AND role = 'candidato'
      AND COALESCE(ativo, true)
  )
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

CREATE OR REPLACE FUNCTION public.app_my_assessor_id()
RETURNS UUID AS $$
  SELECT a.id FROM assessores a
  INNER JOIN profiles p ON p.id = a.profile_id
  WHERE a.profile_id = auth.uid()
    AND COALESCE(a.ativo, true)
    AND COALESCE(p.ativo, true)
  LIMIT 1
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

CREATE OR REPLACE FUNCTION public.app_my_apoiador_id()
RETURNS UUID AS $$
  SELECT ap.id FROM apoiadores ap
  INNER JOIN profiles p ON p.id = ap.profile_id
  WHERE ap.profile_id = auth.uid()
    AND COALESCE(ap.ativo, true)
    AND COALESCE(p.ativo, true)
  LIMIT 1
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

GRANT EXECUTE ON FUNCTION public.app_is_candidato() TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_my_assessor_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_my_apoiador_id() TO authenticated;

-- Mesma lógica que auth.assessor_ids_do_candidato (migração 50310000007); em hosted auth.* pode não existir.
CREATE OR REPLACE FUNCTION public.app_assessor_ids_do_candidato()
RETURNS SETOF UUID AS $$
  SELECT a.id FROM assessores a
  WHERE a.profile_id = auth.uid()
  OR a.profile_id IN (SELECT id FROM profiles WHERE invited_by = auth.uid())
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

GRANT EXECUTE ON FUNCTION public.app_assessor_ids_do_candidato() TO authenticated;

-- Candidato desativa/reativa assessor da campanha (não o próprio registro ligado ao deputado)
CREATE OR REPLACE FUNCTION public.candidato_set_assessor_ativo(p_assessor_id UUID, p_ativo BOOLEAN)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile UUID;
  v_me_assessor UUID;
BEGIN
  IF NOT public.app_is_candidato() THEN
    RAISE EXCEPTION 'Apenas o candidato pode alterar o status do assessor.';
  END IF;

  SELECT id INTO v_me_assessor FROM assessores WHERE profile_id = auth.uid() LIMIT 1;
  IF v_me_assessor IS NOT NULL AND p_assessor_id = v_me_assessor THEN
    RAISE EXCEPTION 'Não é possível desativar o registro de assessor vinculado ao próprio candidato.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM assessores a
    WHERE a.id = p_assessor_id
      AND a.profile_id IN (SELECT id FROM profiles WHERE invited_by = auth.uid())
  ) THEN
    RAISE EXCEPTION 'Assessor não pertence à sua campanha.';
  END IF;

  SELECT profile_id INTO v_profile FROM assessores WHERE id = p_assessor_id;
  IF v_profile IS NULL THEN
    RAISE EXCEPTION 'Assessor sem perfil vinculado.';
  END IF;

  UPDATE assessores SET ativo = p_ativo WHERE id = p_assessor_id;
  UPDATE profiles SET ativo = p_ativo WHERE id = v_profile;
END;
$$;

COMMENT ON FUNCTION public.candidato_set_assessor_ativo IS 'Candidato: desativa ou reativa assessor convidado (acesso ao app e RLS).';

-- Candidato remove vínculo de login do apoiador; mantém linha em apoiadores e dados cadastrais
CREATE OR REPLACE FUNCTION public.candidato_revogar_acesso_apoiador(p_apoiador_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prof UUID;
  v_assessor UUID;
BEGIN
  IF NOT public.app_is_candidato() THEN
    RAISE EXCEPTION 'Apenas o candidato pode revogar o acesso do apoiador.';
  END IF;

  SELECT assessor_id, profile_id INTO v_assessor, v_prof
  FROM apoiadores WHERE id = p_apoiador_id;

  IF v_assessor IS NULL THEN
    RAISE EXCEPTION 'Apoiador não encontrado.';
  END IF;

  IF NOT (v_assessor IN (SELECT public.app_assessor_ids_do_candidato())) THEN
    RAISE EXCEPTION 'Apoiador não pertence à sua campanha.';
  END IF;

  UPDATE apoiadores SET profile_id = NULL WHERE id = p_apoiador_id;

  IF v_prof IS NOT NULL THEN
    UPDATE profiles SET ativo = false WHERE id = v_prof;
  END IF;
END;
$$;

COMMENT ON FUNCTION public.candidato_revogar_acesso_apoiador IS 'Candidato: remove profile_id do apoiador e desativa o perfil de login; dados do apoiador permanecem.';

GRANT EXECUTE ON FUNCTION public.candidato_set_assessor_ativo(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.candidato_revogar_acesso_apoiador(UUID) TO authenticated;
