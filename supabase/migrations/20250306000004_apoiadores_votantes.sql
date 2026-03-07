-- Apoiadores (PF/PJ) e Votantes

CREATE TABLE apoiadores (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  profile_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  assessor_id UUID NOT NULL REFERENCES assessores(id) ON DELETE RESTRICT,
  nome TEXT NOT NULL,
  tipo tipo_pessoa NOT NULL DEFAULT 'PF',
  perfil TEXT, -- Prefeitural, Vereador(a), Líder Religional, Empresarial, etc.
  telefone TEXT,
  email TEXT,
  estimativa_votos INTEGER DEFAULT 0,
  cidades_atuacao UUID[] DEFAULT '{}', -- array de municipios.id
  ativo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE votantes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  profile_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  assessor_id UUID REFERENCES assessores(id) ON DELETE SET NULL,
  apoiador_id UUID REFERENCES apoiadores(id) ON DELETE SET NULL,
  nome TEXT NOT NULL,
  telefone TEXT,
  email TEXT,
  municipio_id UUID REFERENCES municipios(id) ON DELETE SET NULL,
  abrangencia abrangencia_voto NOT NULL DEFAULT 'Individual',
  qtd_votos_familia INTEGER DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_apoiadores_assessor ON apoiadores(assessor_id);
CREATE INDEX idx_apoiadores_profile ON apoiadores(profile_id);
CREATE INDEX idx_votantes_assessor ON votantes(assessor_id);
CREATE INDEX idx_votantes_apoiador ON votantes(apoiador_id);
CREATE INDEX idx_votantes_municipio ON votantes(municipio_id);

CREATE TRIGGER apoiadores_updated_at BEFORE UPDATE ON apoiadores
  FOR EACH ROW EXECUTE PROCEDURE set_updated_at();
CREATE TRIGGER votantes_updated_at BEFORE UPDATE ON votantes
  FOR EACH ROW EXECUTE PROCEDURE set_updated_at();
