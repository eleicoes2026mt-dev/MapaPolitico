-- Cadastro público com convite por apoiador: a linha em votantes tem apoiador_id preenchido.
-- A política antiga exigia apoiador_id IS NULL no WITH CHECK, bloqueando UPDATE (cidade, etc.)
-- após o signup. O candidato conseguia corrigir pelo painel (política votantes_candidato).

DROP POLICY IF EXISTS "votantes_votante_qr_own" ON public.votantes;
CREATE POLICY "votantes_votante_qr_own" ON public.votantes
  FOR ALL TO authenticated
  USING (
    public.app_is_profile_votante_qr()
    AND profile_id = auth.uid()
  )
  WITH CHECK (
    public.app_is_profile_votante_qr()
    AND profile_id = auth.uid()
    AND assessor_id = public.app_assessor_id_do_candidato()
    AND (
      apoiador_id IS NULL
      OR EXISTS (
        SELECT 1
        FROM public.apoiadores a
        INNER JOIN public.profiles pr ON pr.id = auth.uid()
        WHERE a.id = apoiador_id
          AND pr.indicado_por_profile_id IS NOT NULL
          AND a.profile_id = pr.indicado_por_profile_id
      )
    )
  );

COMMENT ON POLICY "votantes_votante_qr_own" ON public.votantes IS
  'Votante atualiza a própria linha; apoiador_id só se alinha ao convite (indicado_por_profile_id).';
