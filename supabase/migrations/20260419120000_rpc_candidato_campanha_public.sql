-- Foto/nome do candidato para o cartão de convite (QR): apoiadores/votantes não leem outros profiles por RLS.
CREATE OR REPLACE FUNCTION public.candidato_campanha_public()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'id', p.id,
    'full_name', p.full_name,
    'avatar_url', p.avatar_url,
    'partido_bandeira_url', pt.bandeira_url
  )
  FROM public.profiles p
  LEFT JOIN public.partidos pt ON pt.id = p.partido_id
  WHERE p.role = 'candidato'::app_role
  LIMIT 1;
$$;

COMMENT ON FUNCTION public.candidato_campanha_public() IS
  'Retorna id, nome e URLs de imagem do candidato da campanha (cartão convite / QR); não expõe outros perfis.';

GRANT EXECUTE ON FUNCTION public.candidato_campanha_public() TO authenticated;
