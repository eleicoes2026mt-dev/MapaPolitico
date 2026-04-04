-- Cadastro público «Amigos do Gilberto»: ao criar conta (auth), gravar também em public.votantes
-- com profile_id, para aparecer na lista do candidato sem passar de novo pelo formulário.

CREATE OR REPLACE FUNCTION public.ensure_votante_amigos_cadastro()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_assessor uuid;
  v_prof public.profiles%ROWTYPE;
  v_nome text;
BEGIN
  SELECT * INTO v_prof FROM public.profiles WHERE id = auth.uid();
  IF NOT FOUND THEN
    RETURN;
  END IF;
  IF v_prof.role IS DISTINCT FROM 'votante'::public.app_role
     OR NOT COALESCE(v_prof.cadastro_via_qr, false) THEN
    RETURN;
  END IF;
  IF EXISTS (SELECT 1 FROM public.votantes WHERE profile_id = auth.uid()) THEN
    RETURN;
  END IF;

  SELECT public.app_assessor_id_do_candidato() INTO v_assessor;
  IF v_assessor IS NULL THEN
    RETURN;
  END IF;

  PERFORM set_config('row_security', 'off', true);

  v_nome := COALESCE(
    NULLIF(TRIM(v_prof.full_name), ''),
    split_part(COALESCE(v_prof.email, ''), '@', 1),
    'Amigo'
  );

  INSERT INTO public.votantes (
    profile_id,
    assessor_id,
    nome,
    email,
    apoiador_id,
    cadastro_via_qr,
    abrangencia,
    qtd_votos_familia
  ) VALUES (
    auth.uid(),
    v_assessor,
    v_nome,
    v_prof.email,
    NULL,
    true,
    'Individual'::public.abrangencia_voto,
    1
  );
END;
$$;

COMMENT ON FUNCTION public.ensure_votante_amigos_cadastro() IS
  'Idempotente: cria linha em votantes para perfil votante + cadastro_via_qr (link Amigos do Gilberto).';

GRANT EXECUTE ON FUNCTION public.ensure_votante_amigos_cadastro() TO authenticated;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_raw text := lower(trim(COALESCE(NEW.raw_user_meta_data->>'role', '')));
  v_role public.app_role := 'votante'::public.app_role;
  v_cadastro_qr boolean := false;
  v_assessor uuid;
  v_nome text;
BEGIN
  IF v_raw IN ('candidato', 'assessor', 'apoiador', 'votante') THEN
    v_role := v_raw::public.app_role;
  END IF;

  IF NEW.raw_user_meta_data ? 'cadastro_via_qr' THEN
    v_cadastro_qr := COALESCE((NEW.raw_user_meta_data->>'cadastro_via_qr')::boolean, false);
  END IF;

  PERFORM set_config('row_security', 'off', true);

  INSERT INTO public.profiles (id, full_name, email, role, cadastro_via_qr)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
    NEW.email,
    v_role,
    v_cadastro_qr
  )
  ON CONFLICT (id) DO UPDATE SET
    full_name = COALESCE(NULLIF(EXCLUDED.full_name, ''), profiles.full_name),
    email = COALESCE(EXCLUDED.email, profiles.email),
    role = CASE
      WHEN profiles.role IS DISTINCT FROM 'votante'::public.app_role THEN profiles.role
      ELSE EXCLUDED.role
    END,
    cadastro_via_qr = profiles.cadastro_via_qr OR EXCLUDED.cadastro_via_qr;

  IF v_role = 'votante'::public.app_role AND v_cadastro_qr THEN
    SELECT public.app_assessor_id_do_candidato() INTO v_assessor;
    v_nome := COALESCE(
      NULLIF(TRIM(COALESCE(NEW.raw_user_meta_data->>'full_name', '')), ''),
      split_part(COALESCE(NEW.email, ''), '@', 1),
      'Amigo'
    );
    IF v_assessor IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM public.votantes WHERE profile_id = NEW.id
    ) THEN
      INSERT INTO public.votantes (
        profile_id,
        assessor_id,
        nome,
        email,
        apoiador_id,
        cadastro_via_qr,
        abrangencia,
        qtd_votos_familia
      ) VALUES (
        NEW.id,
        v_assessor,
        v_nome,
        NEW.email,
        NULL,
        true,
        'Individual'::public.abrangencia_voto,
        1
      );
    END IF;
  END IF;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.handle_new_user() IS
  'Cria/atualiza profiles no signup; persiste cadastro_via_qr; cria votantes para Amigos do Gilberto.';
