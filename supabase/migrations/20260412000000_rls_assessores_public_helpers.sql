-- A tabela apoiadores já usava public.app_is_candidato / app_assessor_ids_do_candidato (20260404140000).
-- assessores continuava com auth.is_candidato() — em alguns ambientes a função em auth.* não resolve
-- public.profiles e retorna false; o candidato só enxergava a própria linha (assessores_own), o app filtra
-- essa linha e a lista de assessores ficava vazia.

CREATE OR REPLACE FUNCTION public.can_see_assessor(assessor_uuid UUID)
RETURNS BOOLEAN AS $$
  SELECT (
    public.app_is_candidato()
    AND assessor_uuid IN (SELECT public.app_assessor_ids_do_candidato())
  )
  OR (public.app_my_assessor_id() = assessor_uuid)
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

COMMENT ON FUNCTION public.can_see_assessor(UUID) IS
  'Substitui auth.can_see_assessor para RLS em assessores; usa public.app_* com search_path fixo.';

GRANT EXECUTE ON FUNCTION public.can_see_assessor(UUID) TO authenticated;

DROP POLICY IF EXISTS "assessores_candidato" ON public.assessores;
CREATE POLICY "assessores_candidato" ON public.assessores FOR ALL TO authenticated
  USING (
    public.app_is_candidato()
    AND id IN (SELECT public.app_assessor_ids_do_candidato())
  );

DROP POLICY IF EXISTS "assessores_read_own" ON public.assessores;
CREATE POLICY "assessores_read_own" ON public.assessores FOR SELECT TO authenticated
  USING (public.can_see_assessor(id));
