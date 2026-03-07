-- Benfeitorias, Metas Regionais, Reuniões, Concorrentes

CREATE TABLE benfeitorias (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  apoiador_id UUID NOT NULL REFERENCES apoiadores(id) ON DELETE CASCADE,
  municipio_id UUID REFERENCES municipios(id) ON DELETE SET NULL,
  titulo TEXT NOT NULL,
  descricao TEXT,
  valor DECIMAL(14,2) NOT NULL DEFAULT 0,
  data_realizacao DATE,
  tipo tipo_benfeitoria DEFAULT 'Outro',
  status status_benfeitoria NOT NULL DEFAULT 'em_andamento',
  foto_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE metas_regionais (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  polo_id UUID NOT NULL REFERENCES polos_regioes(id) ON DELETE CASCADE,
  meta_votos INTEGER NOT NULL DEFAULT 0,
  percentual_distribuicao DECIMAL(5,2) DEFAULT 0,
  responsavel_id UUID REFERENCES assessores(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(polo_id)
);

-- Meta estadual única (singleton)
CREATE TABLE meta_estadual (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  meta_votos INTEGER NOT NULL DEFAULT 50000,
  updated_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO meta_estadual (meta_votos) VALUES (50000);

CREATE TABLE reunioes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  titulo TEXT NOT NULL,
  local_texto TEXT,
  data_reuniao DATE NOT NULL,
  hora TIME,
  cidades_alvo UUID[] DEFAULT '{}',
  polo_id UUID REFERENCES polos_regioes(id) ON DELETE SET NULL,
  criado_por UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE concorrentes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nome TEXT NOT NULL,
  cargo TEXT,
  votos_ultima_eleicao INTEGER DEFAULT 0,
  municipio_ref TEXT,
  partido TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_benfeitorias_apoiador ON benfeitorias(apoiador_id);
CREATE INDEX idx_benfeitorias_municipio ON benfeitorias(municipio_id);
CREATE INDEX idx_metas_regionais_polo ON metas_regionais(polo_id);
CREATE INDEX idx_reunioes_data ON reunioes(data_reuniao);

CREATE TRIGGER benfeitorias_updated_at BEFORE UPDATE ON benfeitorias
  FOR EACH ROW EXECUTE PROCEDURE set_updated_at();
CREATE TRIGGER metas_regionais_updated_at BEFORE UPDATE ON metas_regionais
  FOR EACH ROW EXECUTE PROCEDURE set_updated_at();
CREATE TRIGGER reunioes_updated_at BEFORE UPDATE ON reunioes
  FOR EACH ROW EXECUTE PROCEDURE set_updated_at();
