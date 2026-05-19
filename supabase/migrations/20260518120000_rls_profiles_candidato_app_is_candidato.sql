-- Alinha profiles com assessores/apoiadores: gestor da campanha inclui assessor ativo grau 1.
-- Antes: profiles_candidato_all usava apenas auth.is_candidato() (role = candidato),
--        bloqueando SELECT na linha do candidato (ex.: sq_candidato_tse_2022) para grau 1.

DROP POLICY IF EXISTS "profiles_candidato_all" ON public.profiles;

CREATE POLICY "profiles_candidato_all" ON public.profiles
  FOR ALL TO authenticated
  USING (public.app_is_candidato())
  WITH CHECK (public.app_is_candidato());

COMMENT ON POLICY "profiles_candidato_all" ON public.profiles IS
  'Candidato ou assessor grau 1 (app_is_candidato): leitura/escrita como gestor da campanha.';
