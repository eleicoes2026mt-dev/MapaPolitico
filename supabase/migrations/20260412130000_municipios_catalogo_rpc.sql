-- Catálogo de municípios para o app: popula se vazio (mesma lógica da seed_municipios_mt_if_empty)
-- e devolve as linhas na resposta da RPC. Assim o cliente não depende só de SELECT em municipios
-- (útil se RLS ou rede falharem no caminho direto).

CREATE OR REPLACE FUNCTION public.municipios_catalogo_para_app()
RETURNS SETOF public.municipios
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.municipios LIMIT 1) THEN
    BEGIN
      PERFORM public.seed_municipios_mt_if_empty();
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  END IF;
  RETURN QUERY SELECT * FROM public.municipios ORDER BY nome;
END;
$$;

COMMENT ON FUNCTION public.municipios_catalogo_para_app() IS
  'Lista municípios MT; executa seed no servidor se a tabela estiver vazia (bypass RLS na leitura interna).';

REVOKE ALL ON FUNCTION public.municipios_catalogo_para_app() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.municipios_catalogo_para_app() TO authenticated;
GRANT EXECUTE ON FUNCTION public.municipios_catalogo_para_app() TO anon;
