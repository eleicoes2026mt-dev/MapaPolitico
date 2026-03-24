-- Endereço estruturado (opcional) para votantes, apoiadores e assessores.

ALTER TABLE votantes ADD COLUMN IF NOT EXISTS cep TEXT;
ALTER TABLE votantes ADD COLUMN IF NOT EXISTS logradouro TEXT;
ALTER TABLE votantes ADD COLUMN IF NOT EXISTS numero TEXT;
ALTER TABLE votantes ADD COLUMN IF NOT EXISTS complemento TEXT;

ALTER TABLE apoiadores ADD COLUMN IF NOT EXISTS cep TEXT;
ALTER TABLE apoiadores ADD COLUMN IF NOT EXISTS logradouro TEXT;
ALTER TABLE apoiadores ADD COLUMN IF NOT EXISTS numero TEXT;
ALTER TABLE apoiadores ADD COLUMN IF NOT EXISTS complemento TEXT;

ALTER TABLE assessores ADD COLUMN IF NOT EXISTS cep TEXT;
ALTER TABLE assessores ADD COLUMN IF NOT EXISTS logradouro TEXT;
ALTER TABLE assessores ADD COLUMN IF NOT EXISTS numero TEXT;
ALTER TABLE assessores ADD COLUMN IF NOT EXISTS complemento TEXT;

COMMENT ON COLUMN votantes.cep IS 'CEP (opcional)';
COMMENT ON COLUMN apoiadores.cep IS 'CEP (opcional)';
COMMENT ON COLUMN assessores.cep IS 'CEP (opcional)';
