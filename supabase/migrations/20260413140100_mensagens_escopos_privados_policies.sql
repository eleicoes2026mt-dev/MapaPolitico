-- Políticas RLS de mensagens (executa numa transação separada após os novos valores do enum).

-- Antes qualquer autenticado lia todas as linhas (mensagens_read).
DROP POLICY IF EXISTS "mensagens_read" ON public.mensagens;

DROP POLICY IF EXISTS "mensagens_candidato" ON public.mensagens;
CREATE POLICY "mensagens_candidato" ON public.mensagens
  FOR ALL TO authenticated
  USING (
    public.app_is_candidato()
    OR public.app_my_assessor_id() IS NOT NULL
  )
  WITH CHECK (
    public.app_is_candidato()
    OR public.app_my_assessor_id() IS NOT NULL
  );

COMMENT ON POLICY "mensagens_candidato" ON public.mensagens IS
  'Candidato ou assessor da campanha: CRUD em mensagens.';

DROP POLICY IF EXISTS "mensagens_apoiador_read" ON public.mensagens;
CREATE POLICY "mensagens_apoiador_read" ON public.mensagens
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.profiles pr WHERE pr.id = auth.uid() AND pr.role = 'apoiador')
    AND (
      escopo IN ('global', 'polo', 'performance', 'reuniao', 'privada_apoiadores')
      OR (
        escopo = 'cidade'
        AND EXISTS (
          SELECT 1
          FROM public.apoiadores a
          WHERE a.profile_id = auth.uid()
            AND a.municipio_id IS NOT NULL
            AND a.municipio_id = ANY (municipios_ids)
        )
      )
    )
  );

COMMENT ON POLICY "mensagens_apoiador_read" ON public.mensagens IS
  'Apoiador: globais, polo, performance, reunião, privada_apoiadores, ou cidade onde está cadastrado.';

DROP POLICY IF EXISTS "mensagens_votante_read" ON public.mensagens;
CREATE POLICY "mensagens_votante_read" ON public.mensagens
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.profiles pr WHERE pr.id = auth.uid() AND pr.role = 'votante')
    AND (
      escopo IN ('global', 'polo', 'performance', 'reuniao')
      OR (
        escopo = 'cidade'
        AND EXISTS (
          SELECT 1
          FROM public.votantes v
          WHERE v.profile_id = auth.uid()
            AND v.municipio_id IS NOT NULL
            AND v.municipio_id = ANY (municipios_ids)
        )
      )
    )
  );

COMMENT ON POLICY "mensagens_votante_read" ON public.mensagens IS
  'Votante: globais ou mensagens da cidade em que está cadastrado.';
