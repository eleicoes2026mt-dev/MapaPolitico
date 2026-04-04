-- Convite assessor/apoiador: o trigger handle_new_user (fix 20250306000011) passou a inserir
-- sempre 'votante', ignorando user_metadata.role do inviteUserByEmail (invite-metadata.ts).
-- Isto fazia o perfil começar como votante; em falhas de ordem/upsert o papel ficava errado.
--
-- 1) Trigger: lê role seguro a partir de raw_user_meta_data (convite envia role apoiador/assessor).
-- 2) ON CONFLICT: não rebaixa candidato/assessor/apoiador para votante.
-- 3) Repara linhas já inconsistentes (tem apoiadores/assessores mas role = votante).

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_raw text := lower(trim(COALESCE(NEW.raw_user_meta_data->>'role', '')));
  v_role app_role := 'votante'::app_role;
BEGIN
  IF v_raw IN ('candidato', 'assessor', 'apoiador', 'votante') THEN
    v_role := v_raw::app_role;
  END IF;

  INSERT INTO public.profiles (id, full_name, email, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
    NEW.email,
    v_role
  )
  ON CONFLICT (id) DO UPDATE SET
    full_name = COALESCE(NULLIF(EXCLUDED.full_name, ''), profiles.full_name),
    email = COALESCE(EXCLUDED.email, profiles.email),
    role = CASE
      WHEN profiles.role IS DISTINCT FROM 'votante'::app_role THEN profiles.role
      ELSE EXCLUDED.role
    END;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.handle_new_user() IS
  'Cria/atualiza profiles no signup; convite usa role em user_metadata; não rebaixa papel já elevado.';

-- Perfil apoiador/assessor com role votante (legado / trigger errado)
UPDATE public.profiles p
SET role = 'apoiador'::app_role, updated_at = now()
WHERE p.role = 'votante'::app_role
  AND EXISTS (
    SELECT 1 FROM public.apoiadores a
    WHERE a.profile_id = p.id
      AND (a.excluido_em IS NULL)
  );

UPDATE public.profiles p
SET role = 'assessor'::app_role, updated_at = now()
WHERE p.role = 'votante'::app_role
  AND EXISTS (
    SELECT 1 FROM public.assessores s
    WHERE s.profile_id = p.id
      AND COALESCE(s.ativo, true) = true
  );
