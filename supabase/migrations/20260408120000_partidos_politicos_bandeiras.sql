-- Partidos políticos com bandeira; candidato escolhe partido no perfil.

CREATE TABLE IF NOT EXISTS public.partidos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sigla TEXT NOT NULL,
  nome TEXT NOT NULL,
  bandeira_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users (id) ON DELETE SET NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS partidos_sigla_lower ON public.partidos (lower(sigla));

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS partido_id UUID REFERENCES public.partidos (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_profiles_partido_id ON public.profiles (partido_id);

ALTER TABLE public.partidos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "partidos_read_authenticated" ON public.partidos;
CREATE POLICY "partidos_read_authenticated" ON public.partidos
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "partidos_insert_candidato" ON public.partidos;
CREATE POLICY "partidos_insert_candidato" ON public.partidos
  FOR INSERT TO authenticated
  WITH CHECK (public.app_is_candidato());

DROP POLICY IF EXISTS "partidos_update_candidato" ON public.partidos;
CREATE POLICY "partidos_update_candidato" ON public.partidos
  FOR UPDATE TO authenticated
  USING (public.app_is_candidato())
  WITH CHECK (public.app_is_candidato());

DROP POLICY IF EXISTS "partidos_delete_candidato" ON public.partidos;
CREATE POLICY "partidos_delete_candidato" ON public.partidos
  FOR DELETE TO authenticated
  USING (public.app_is_candidato());

COMMENT ON TABLE public.partidos IS 'Partidos cadastrados pelo candidato; bandeira em storage público.';

-- Bucket para imagens de bandeira (público leitura)
INSERT INTO storage.buckets (id, name, public)
VALUES ('bandeiras', 'bandeiras', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "bandeiras_select_public" ON storage.objects;
CREATE POLICY "bandeiras_select_public" ON storage.objects
  FOR SELECT TO public
  USING (bucket_id = 'bandeiras');

DROP POLICY IF EXISTS "bandeiras_insert_authenticated" ON storage.objects;
CREATE POLICY "bandeiras_insert_authenticated" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'bandeiras');

DROP POLICY IF EXISTS "bandeiras_update_authenticated" ON storage.objects;
CREATE POLICY "bandeiras_update_authenticated" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'bandeiras');

DROP POLICY IF EXISTS "bandeiras_delete_authenticated" ON storage.objects;
CREATE POLICY "bandeiras_delete_authenticated" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'bandeiras');
