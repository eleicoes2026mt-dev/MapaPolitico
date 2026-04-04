-- Se já aplicou 20260415120000 com a condição cadastro_via_qr, esta migração
-- alarga a função para qualquer perfil com role=votante (evita INSERT bloqueado).

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
