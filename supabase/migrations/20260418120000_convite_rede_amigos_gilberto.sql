-- Rede de convites Amigos do Gilberto: quem gera o QR/link (ref=perfil) fica registrado como
-- indicador; novos votantes vinculam-se em convite_por_profile_id e, se o indicador for apoiador, apoiador_id.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS indicado_por_profile_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.profiles.indicado_por_profile_id IS
  'Perfil que convidou por link/QR (metadata convite_por no signup).';

ALTER TABLE public.votantes
  ADD COLUMN IF NOT EXISTS convite_por_profile_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.votantes.convite_por_profile_id IS
  'Perfil que gerou o link/QR; opcionalmente apoiador_id preenchido quando o mesmo é apoiador.';

CREATE INDEX IF NOT EXISTS idx_votantes_convite_por_profile_id ON public.votantes (convite_por_profile_id);

ALTER TABLE public.votantes
  ADD COLUMN IF NOT EXISTS convite_por_nome TEXT;

COMMENT ON COLUMN public.votantes.convite_por_nome IS
  'Nome do perfil convidador (denormalizado; RLS em profiles impede join no cliente).';

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
  v_convite uuid;
  v_apoiador uuid;
  v_convite_nome text;
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

  v_convite := v_prof.indicado_por_profile_id;
  v_convite_nome := NULL;
  v_apoiador := NULL;
  IF v_convite IS NOT NULL THEN
    SELECT id INTO v_apoiador FROM public.apoiadores WHERE profile_id = v_convite LIMIT 1;
    SELECT NULLIF(TRIM(full_name), '') INTO v_convite_nome FROM public.profiles WHERE id = v_convite LIMIT 1;
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
    convite_por_profile_id,
    convite_por_nome,
    cadastro_via_qr,
    abrangencia,
    qtd_votos_familia
  ) VALUES (
    auth.uid(),
    v_assessor,
    v_nome,
    v_prof.email,
    v_apoiador,
    v_convite,
    v_convite_nome,
    true,
    'Individual'::public.abrangencia_voto,
    1
  );
END;
$$;

COMMENT ON FUNCTION public.ensure_votante_amigos_cadastro() IS
  'Idempotente: cria linha em votantes para perfil votante + cadastro_via_qr (link Amigos do Gilberto).';

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
        qtd_votos_familia
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
  'Cria/atualiza profiles (incl. indicado_por); cria votantes com convite/apoiador por rede.';
