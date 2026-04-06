-- Lugares de procedência / "de onde é" reutilizáveis por campanha (assessor).
-- Cada assessor mantém o próprio catálogo; apoiadores referenciam um lugar opcional.

CREATE TABLE IF NOT EXISTS public.apoiador_origem_lugares (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  assessor_id uuid NOT NULL REFERENCES public.assessores(id) ON DELETE CASCADE,
  nome text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT apoiador_origem_lugares_nome_nao_vazio CHECK (char_length(btrim(nome)) >= 1)
);

COMMENT ON TABLE public.apoiador_origem_lugares IS
  'Catálogo de lugares (ex.: cidade, comunidade) para marcar a procedência do apoiador; reutilizável entre cadastros.';
COMMENT ON COLUMN public.apoiador_origem_lugares.nome IS
  'Texto livre (ex.: Cáceres, Sindicato X, Região norte).';

CREATE UNIQUE INDEX IF NOT EXISTS apoiador_origem_lugares_assessor_nome_lower
  ON public.apoiador_origem_lugares (assessor_id, lower(btrim(nome)));

CREATE INDEX IF NOT EXISTS idx_apoiador_origem_lugares_assessor
  ON public.apoiador_origem_lugares (assessor_id);

ALTER TABLE public.apoiadores
  ADD COLUMN IF NOT EXISTS origem_lugar_id uuid REFERENCES public.apoiador_origem_lugares(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.apoiadores.origem_lugar_id IS
  'Opcional: lugar de procedência escolhido do catálogo do assessor.';

ALTER TABLE public.apoiador_origem_lugares ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "apoiador_origem_lugares_select" ON public.apoiador_origem_lugares;
CREATE POLICY "apoiador_origem_lugares_select" ON public.apoiador_origem_lugares
  FOR SELECT TO authenticated
  USING (
    assessor_id IN (SELECT public.app_assessor_ids_do_candidato())
    OR assessor_id = public.app_my_assessor_id()
  );

DROP POLICY IF EXISTS "apoiador_origem_lugares_insert" ON public.apoiador_origem_lugares;
CREATE POLICY "apoiador_origem_lugares_insert" ON public.apoiador_origem_lugares
  FOR INSERT TO authenticated
  WITH CHECK (
    assessor_id IN (SELECT public.app_assessor_ids_do_candidato())
    OR assessor_id = public.app_my_assessor_id()
  );

DROP POLICY IF EXISTS "apoiador_origem_lugares_update" ON public.apoiador_origem_lugares;
CREATE POLICY "apoiador_origem_lugares_update" ON public.apoiador_origem_lugares
  FOR UPDATE TO authenticated
  USING (
    assessor_id IN (SELECT public.app_assessor_ids_do_candidato())
    OR assessor_id = public.app_my_assessor_id()
  )
  WITH CHECK (
    assessor_id IN (SELECT public.app_assessor_ids_do_candidato())
    OR assessor_id = public.app_my_assessor_id()
  );

DROP POLICY IF EXISTS "apoiador_origem_lugares_delete" ON public.apoiador_origem_lugares;
CREATE POLICY "apoiador_origem_lugares_delete" ON public.apoiador_origem_lugares
  FOR DELETE TO authenticated
  USING (
    assessor_id IN (SELECT public.app_assessor_ids_do_candidato())
    OR assessor_id = public.app_my_assessor_id()
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON public.apoiador_origem_lugares TO authenticated;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'apoiador_origem_lugares'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.apoiador_origem_lugares;
  END IF;
END $$;
