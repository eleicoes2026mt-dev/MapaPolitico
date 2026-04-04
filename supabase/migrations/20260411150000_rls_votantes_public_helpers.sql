-- Votantes: alinhar políticas a public.app_* (hosted / RLS).
-- As políticas antigas usavam auth.is_candidato() e auth.assessor_ids_do_candidato();
-- se o schema auth não tiver as mesmas funções ou o JWT não alinhar, INSERT em votantes falha (42501).

DROP POLICY IF EXISTS "votantes_candidato" ON public.votantes;
CREATE POLICY "votantes_candidato" ON public.votantes
  FOR ALL TO authenticated
  USING (
    public.app_is_candidato()
    AND assessor_id IN (SELECT public.app_assessor_ids_do_candidato())
  )
  WITH CHECK (
    public.app_is_candidato()
    AND assessor_id IN (SELECT public.app_assessor_ids_do_candidato())
  );

DROP POLICY IF EXISTS "votantes_assessor" ON public.votantes;
CREATE POLICY "votantes_assessor" ON public.votantes
  FOR ALL TO authenticated
  USING (assessor_id = public.app_my_assessor_id())
  WITH CHECK (assessor_id = public.app_my_assessor_id());

-- votantes_apoiador_all (604041400) já usa public.app_*; mantém-se.
