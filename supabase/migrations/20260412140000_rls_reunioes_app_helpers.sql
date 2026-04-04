-- INSERT em reunioes falhava com 42501: política usava auth.is_candidato() (search_path / hosted).
-- Alinha com apoiadores/assessores: public.app_* e permite assessor da campanha agendar visitas.

DROP POLICY IF EXISTS "reunioes_candidato" ON public.reunioes;
CREATE POLICY "reunioes_candidato" ON public.reunioes
  FOR ALL TO authenticated
  USING (
    public.app_is_candidato()
    OR public.app_my_assessor_id() IS NOT NULL
  )
  WITH CHECK (
    public.app_is_candidato()
    OR public.app_my_assessor_id() IS NOT NULL
  );

COMMENT ON POLICY "reunioes_candidato" ON public.reunioes IS
  'Candidato ou utilizador com registo em assessores (nível 2) pode CRUD em reunioes/visitas.';
