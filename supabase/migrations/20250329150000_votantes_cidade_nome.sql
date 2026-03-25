-- Coluna de texto livre para cidade do votante.
-- Salva o nome mesmo quando municipio_id não pôde ser resolvido (tabela municipios vazia).
ALTER TABLE votantes ADD COLUMN IF NOT EXISTS cidade_nome TEXT;

-- Índice para filtro/busca por cidade.
CREATE INDEX IF NOT EXISTS idx_votantes_cidade_nome ON votantes(cidade_nome);
