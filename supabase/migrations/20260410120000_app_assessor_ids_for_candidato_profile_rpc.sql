-- Mesma lógica que public.app_assessor_ids_do_candidato() (RLS em apoiadores),
-- mas recebe o UUID do perfil do candidato para uso nas Edge Functions (service role),
-- onde auth.uid() não existe.
--
-- Evita divergência entre o gate TypeScript (getCandidatoTeamProfileIds + profile_id)
-- e as políticas, que bloqueavam o convite com 403 antes de inviteUserByEmail.

CREATE OR REPLACE FUNCTION public.app_assessor_ids_for_candidato_profile(p_candidato uuid)
RETURNS SETOF uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT a.id
  FROM assessores a
  WHERE a.profile_id = p_candidato
     OR a.profile_id IN (SELECT id FROM profiles WHERE invited_by = p_candidato)
$$;

COMMENT ON FUNCTION public.app_assessor_ids_for_candidato_profile(uuid) IS
  'IDs em assessores.id acessíveis ao candidato (igual app_assessor_ids_do_candidato); para Edge Functions.';

GRANT EXECUTE ON FUNCTION public.app_assessor_ids_for_candidato_profile(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_assessor_ids_for_candidato_profile(uuid) TO service_role;
