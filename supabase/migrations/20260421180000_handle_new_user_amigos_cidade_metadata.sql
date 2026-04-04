-- Cidade no cadastro «Amigos do Gilberto»: gravada no trigger a partir do user_metadata.
-- Cobre o caso em que o projeto exige confirmação de e-mail (sem sessão JWT após signUp):
-- o cliente não consegue chamar RPC finalize, mas o trigger já inseriu votantes com cidade/município.

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
  v_convite uuid;
  v_apoiador uuid;
  v_convite_nome text;
  v_amigos_cidade text;
  v_amigos_mun uuid;
  v_mun_raw text;
  v_mun_nome text;
BEGIN
  IF v_raw IN ('candidato', 'assessor', 'apoiador', 'votante') THEN
    v_role := v_raw::public.app_role;
  END IF;

  IF NEW.raw_user_meta_data ? 'cadastro_via_qr' THEN
    v_cadastro_qr := COALESCE((NEW.raw_user_meta_data->>'cadastro_via_qr')::boolean, false);
  END IF;

  v_convite := NULL;
  IF NEW.raw_user_meta_data ? 'convite_por' THEN
    BEGIN
      v_convite := (NEW.raw_user_meta_data->>'convite_por')::uuid;
    EXCEPTION
      WHEN OTHERS THEN
        v_convite := NULL;
    END;
  END IF;

  IF v_convite IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_convite) THEN
    v_convite := NULL;
  END IF;

  v_apoiador := NULL;
  v_convite_nome := NULL;
  IF v_convite IS NOT NULL THEN
    SELECT id INTO v_apoiador FROM public.apoiadores WHERE profile_id = v_convite LIMIT 1;
    SELECT NULLIF(TRIM(full_name), '') INTO v_convite_nome FROM public.profiles WHERE id = v_convite LIMIT 1;
  END IF;

  -- Cidade / município enviados no signup (cadastro público Amigos do Gilberto).
  v_amigos_cidade := NULLIF(
    LEFT(TRIM(COALESCE(NEW.raw_user_meta_data->>'amigos_cidade_nome', '')), 200),
    ''
  );
  v_amigos_mun := NULL;
  v_mun_raw := NEW.raw_user_meta_data->>'amigos_municipio_id';
  IF v_mun_raw IS NOT NULL AND length(trim(v_mun_raw)) = 36 THEN
    BEGIN
      v_amigos_mun := v_mun_raw::uuid;
      IF NOT EXISTS (SELECT 1 FROM public.municipios WHERE id = v_amigos_mun) THEN
        v_amigos_mun := NULL;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        v_amigos_mun := NULL;
    END;
  END IF;

  IF v_amigos_cidade IS NULL AND v_amigos_mun IS NOT NULL THEN
    SELECT NULLIF(TRIM(nome), '') INTO v_mun_nome FROM public.municipios WHERE id = v_amigos_mun LIMIT 1;
    v_amigos_cidade := NULLIF(LEFT(COALESCE(v_mun_nome, ''), 200), '');
  END IF;

  PERFORM set_config('row_security', 'off', true);

  INSERT INTO public.profiles (id, full_name, email, role, cadastro_via_qr, indicado_por_profile_id)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
    NEW.email,
    v_role,
    v_cadastro_qr,
    v_convite
  )
  ON CONFLICT (id) DO UPDATE SET
    full_name = COALESCE(NULLIF(EXCLUDED.full_name, ''), profiles.full_name),
    email = COALESCE(EXCLUDED.email, profiles.email),
    role = CASE
      WHEN profiles.role IS DISTINCT FROM 'votante'::public.app_role THEN profiles.role
      ELSE EXCLUDED.role
    END,
    cadastro_via_qr = profiles.cadastro_via_qr OR EXCLUDED.cadastro_via_qr,
    indicado_por_profile_id = COALESCE(profiles.indicado_por_profile_id, EXCLUDED.indicado_por_profile_id);

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
        convite_por_profile_id,
        convite_por_nome,
        cadastro_via_qr,
        abrangencia,
        qtd_votos_familia,
        cidade_nome,
        municipio_id
      ) VALUES (
        NEW.id,
        v_assessor,
        v_nome,
        NEW.email,
        v_apoiador,
        v_convite,
        v_convite_nome,
        true,
        'Individual'::public.abrangencia_voto,
        1,
        v_amigos_cidade,
        v_amigos_mun
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
  'Cria/atualiza profiles; cria votantes com convite e cidade/município (metadata amigos_cidade_nome, amigos_municipio_id).';
