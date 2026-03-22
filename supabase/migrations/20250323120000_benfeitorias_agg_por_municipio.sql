-- Agregação de benfeitorias por município (respeita RLS de benfeitorias via SECURITY INVOKER).

CREATE OR REPLACE FUNCTION public.benfeitorias_agg_por_municipio()
RETURNS TABLE (
  municipio_id uuid,
  municipio_nome text,
  qtd bigint,
  valor_total numeric
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT
    b.municipio_id,
    m.nome::text AS municipio_nome,
    COUNT(*)::bigint AS qtd,
    COALESCE(SUM(b.valor), 0)::numeric AS valor_total
  FROM benfeitorias b
  INNER JOIN municipios m ON m.id = b.municipio_id
  WHERE b.municipio_id IS NOT NULL
  GROUP BY b.municipio_id, m.nome;
$$;

COMMENT ON FUNCTION public.benfeitorias_agg_por_municipio() IS 'Contagem e soma de valor de benfeitorias por município; visível conforme políticas RLS em benfeitorias.';

GRANT EXECUTE ON FUNCTION public.benfeitorias_agg_por_municipio() TO authenticated;
