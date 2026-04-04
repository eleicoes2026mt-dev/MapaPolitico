-- Convite assessor/apoiador: "Database error saving new user" no Auth quando RLS em profiles
-- está ativo. O trigger corre no contexto do Auth (ex.: supabase_auth_admin), não como
-- role "authenticated", por isso nenhuma política RLS cobre o INSERT em public.profiles.
-- Desliga RLS só durante o INSERT/UPSERT do perfil (igual promover_candidato_se_vazio).

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_raw text := lower(trim(COALESCE(NEW.raw_user_meta_data->>'role', '')));
  v_role app_role := 'votante'::app_role;
BEGIN
  IF v_raw IN ('candidato', 'assessor', 'apoiador', 'votante') THEN
    v_role := v_raw::app_role;
  END IF;

  PERFORM set_config('row_security', 'off', true);

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
$$;

COMMENT ON FUNCTION public.handle_new_user() IS
  'Cria/atualiza profiles no signup/convite; row_security off no bloco para não falhar com RLS.';
