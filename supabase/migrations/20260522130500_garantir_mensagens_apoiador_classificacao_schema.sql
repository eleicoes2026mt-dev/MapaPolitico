-- Garantias idempotentes: útil quando o projeto remoto ficou atrás ou não correu as migrações
-- `20260520120000_*` / `20260520120100_*`.

-- Escopo novo no enum (ignora se o rótulo já existir — funciona mesmo sem PG 15+ IF NOT EXISTS no ADD VALUE).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_enum e
    INNER JOIN pg_catalog.pg_type t ON e.enumtypid = t.oid
    INNER JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'escopo_mensagem'
      AND e.enumlabel = 'apoiador_classificacao'
  ) THEN
    EXECUTE 'ALTER TYPE public.escopo_mensagem ADD VALUE ''apoiador_classificacao''';
  END IF;
END $$;

ALTER TABLE public.mensagens
  ADD COLUMN IF NOT EXISTS classificacao_apoiador text;

COMMENT ON COLUMN public.mensagens.classificacao_apoiador IS
  'Com escopo apoiador_classificacao: texto da classificação (igual a apoiadores.perfil), comparação trim+lower no RLS.';

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
      OR (
        escopo = 'apoiador_classificacao'
        AND classificacao_apoiador IS NOT NULL
        AND length(trim(classificacao_apoiador)) > 0
        AND EXISTS (
          SELECT 1
          FROM public.apoiadores a
          WHERE a.profile_id = auth.uid()
            AND a.excluido_em IS NULL
            AND a.perfil IS NOT NULL
            AND length(trim(a.perfil)) > 0
            AND lower(trim(a.perfil)) = lower(trim(classificacao_apoiador))
        )
      )
    )
  );

COMMENT ON POLICY "mensagens_apoiador_read" ON public.mensagens IS
  'Apoiador: globais, polo, perf, reunião, privada_apoiadores, cidade onde está cadastrado, ou mesma classificação (perfil).';

NOTIFY pgrst, 'reload schema';
