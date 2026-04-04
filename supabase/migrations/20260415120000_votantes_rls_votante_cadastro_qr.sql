-- Cadastro «Amigos do Gilberto» por link público: perfil role=votante.
-- Permite INSERT/UPDATE/DELETE na própria linha em votantes com assessor_id do candidato.

CREATE OR REPLACE FUNCTION public.app_assessor_id_do_candidato()
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT a.id
  FROM public.assessores a
  INNER JOIN public.profiles p ON p.id = a.profile_id
  WHERE p.role = 'candidato'
  LIMIT 1;
$$;

COMMENT ON FUNCTION public.app_assessor_id_do_candidato() IS
  'Assessor da conta candidato (campanha única). Usado no cadastro QR de votantes.';

GRANT EXECUTE ON FUNCTION public.app_assessor_id_do_candidato() TO authenticated;

CREATE OR REPLACE FUNCTION public.app_is_profile_votante_qr()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = auth.uid()
      AND role = 'votante'
  );
$$;

GRANT EXECUTE ON FUNCTION public.app_is_profile_votante_qr() TO authenticated;

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
    AND apoiador_id IS NULL
    AND assessor_id = public.app_assessor_id_do_candidato()
  );
