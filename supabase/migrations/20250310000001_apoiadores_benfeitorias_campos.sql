-- Campos extras para cadastro completo de apoiadores (PF/PJ) e tipos de benfeitoria

-- Apoiadores: cidade principal e campos PF/PJ
ALTER TABLE apoiadores ADD COLUMN IF NOT EXISTS municipio_id UUID REFERENCES municipios(id) ON DELETE SET NULL;
ALTER TABLE apoiadores ADD COLUMN IF NOT EXISTS cidade_nome TEXT;

-- Pessoa Física
ALTER TABLE apoiadores ADD COLUMN IF NOT EXISTS data_nascimento DATE;
ALTER TABLE apoiadores ADD COLUMN IF NOT EXISTS votos_sozinho BOOLEAN DEFAULT true;
ALTER TABLE apoiadores ADD COLUMN IF NOT EXISTS qtd_votos_familia INTEGER DEFAULT 0;

-- Pessoa Jurídica (dados da API Brasil + responsável)
ALTER TABLE apoiadores ADD COLUMN IF NOT EXISTS cnpj TEXT;
ALTER TABLE apoiadores ADD COLUMN IF NOT EXISTS razao_social TEXT;
ALTER TABLE apoiadores ADD COLUMN IF NOT EXISTS nome_fantasia TEXT;
ALTER TABLE apoiadores ADD COLUMN IF NOT EXISTS situacao_cnpj TEXT;
ALTER TABLE apoiadores ADD COLUMN IF NOT EXISTS endereco TEXT;
ALTER TABLE apoiadores ADD COLUMN IF NOT EXISTS contato_responsavel TEXT;
ALTER TABLE apoiadores ADD COLUMN IF NOT EXISTS email_responsavel TEXT;
ALTER TABLE apoiadores ADD COLUMN IF NOT EXISTS votos_pf INTEGER DEFAULT 0;
ALTER TABLE apoiadores ADD COLUMN IF NOT EXISTS votos_familia INTEGER DEFAULT 0;
ALTER TABLE apoiadores ADD COLUMN IF NOT EXISTS votos_funcionarios INTEGER DEFAULT 0;

-- Índice para listar apoiadores por cidade (mapa)
CREATE INDEX IF NOT EXISTS idx_apoiadores_cidade_nome ON apoiadores(cidade_nome) WHERE cidade_nome IS NOT NULL;

-- Novos valores no enum tipo_benfeitoria (Obra já existe)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'Manutencao' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'tipo_benfeitoria')) THEN
    ALTER TYPE tipo_benfeitoria ADD VALUE 'Manutencao';
  END IF;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'Ajuda_de_custo' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'tipo_benfeitoria')) THEN
    ALTER TYPE tipo_benfeitoria ADD VALUE 'Ajuda_de_custo';
  END IF;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

COMMENT ON COLUMN apoiadores.cidade_nome IS 'Nome do município MT (para mapa quando municipio_id não existir)';
COMMENT ON COLUMN apoiadores.votos_sozinho IS 'PF: true = só votos dele, false = inclui família';
COMMENT ON COLUMN apoiadores.contato_responsavel IS 'PJ: telefone do responsável';
COMMENT ON COLUMN apoiadores.email_responsavel IS 'PJ: e-mail do responsável';
