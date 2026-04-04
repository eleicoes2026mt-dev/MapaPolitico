-- Agrega benfeitorias por município usando COALESCE(benfeitoria.municipio_id, apoiador.municipio_id)
-- para registos antigos ou sem município na própria benfeitoria.

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
    COALESCE(b.municipio_id, a.municipio_id) AS municipio_id,
    m.nome::text AS municipio_nome,
    COUNT(*)::bigint AS qtd,
    COALESCE(SUM(b.valor), 0)::numeric AS valor_total
  FROM benfeitorias b
  INNER JOIN apoiadores a ON a.id = b.apoiador_id
  INNER JOIN municipios m ON m.id = COALESCE(b.municipio_id, a.municipio_id)
  WHERE COALESCE(b.municipio_id, a.municipio_id) IS NOT NULL
  GROUP BY COALESCE(b.municipio_id, a.municipio_id), m.nome;
$$;

COMMENT ON FUNCTION public.benfeitorias_agg_por_municipio() IS
  'Soma benfeitorias por município: usa município da linha ou, se null, município do apoiador. RLS em benfeitorias.';
