-- Tipo e nome do negócio do apoiador (Igreja, Comércio, etc.).
-- Editável pelo próprio apoiador (Meu Perfil) e pelo candidato / assessores grau 1.
ALTER TABLE public.apoiadores
  ADD COLUMN IF NOT EXISTS tipo_negocio TEXT,
  ADD COLUMN IF NOT EXISTS nome_negocio TEXT;

COMMENT ON COLUMN public.apoiadores.tipo_negocio IS
  'Categoria do negócio do apoiador (ex.: Igreja, Comércio, Escola, Sindicato…)';
COMMENT ON COLUMN public.apoiadores.nome_negocio IS
  'Nome do estabelecimento/organização (ex.: Igreja Batista Central, Mercado Boa Sorte…)';
