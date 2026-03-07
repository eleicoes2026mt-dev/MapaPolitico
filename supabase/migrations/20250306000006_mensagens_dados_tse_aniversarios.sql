-- Mensagens, Dados TSE, Aniversariantes

CREATE TABLE mensagens (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  titulo TEXT NOT NULL,
  corpo TEXT,
  escopo escopo_mensagem NOT NULL DEFAULT 'global',
  polo_id UUID REFERENCES polos_regioes(id) ON DELETE SET NULL,
  municipios_ids UUID[] DEFAULT '{}',
  status_performance_filtro status_performance,
  reuniao_id UUID REFERENCES reunioes(id) ON DELETE SET NULL,
  enviada_em TIMESTAMPTZ,
  criado_por UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE dados_tse (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ano_eleicao SMALLINT,
  dt_geracao DATE,
  nm_municipio TEXT,
  cd_municipio TEXT,
  nr_votavel TEXT,
  qt_votos INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_dados_tse_municipio ON dados_tse(nm_municipio);
CREATE INDEX idx_dados_tse_ano ON dados_tse(ano_eleicao);

-- Tabela para aniversariantes (pode ser derivada de profiles/votantes se tiver data_nascimento)
CREATE TABLE aniversariantes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nome TEXT NOT NULL,
  data_nascimento DATE NOT NULL,
  telefone TEXT,
  email TEXT,
  tipo_ref TEXT NOT NULL, -- 'votante'|'apoiador'|'assessor'
  ref_id UUID NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_aniversariantes_dia_mes ON aniversariantes(
  EXTRACT(MONTH FROM data_nascimento),
  EXTRACT(DAY FROM data_nascimento)
);

COMMENT ON TABLE mensagens IS 'Mensagens globais, por polo, cidade, performance ou reunião';
COMMENT ON TABLE dados_tse IS 'Dados importados de CSV TSE para comparativo';
