-- Tabela para dados de votação por seção (TSE). NUNCA dropar: é parte do sistema e contém dados importados.
CREATE TABLE IF NOT EXISTS votacao_secao (
    dt_geracao TEXT,
    hh_geracao TEXT,
    ano_eleicao INTEGER,
    cd_tipo_eleicao INTEGER,
    nm_tipo_eleicao TEXT,
    nr_turno INTEGER,
    cd_eleicao INTEGER,
    ds_eleicao TEXT,
    dt_eleicao TEXT,
    tp_abrangencia TEXT,
    sg_uf TEXT,
    sg_ue TEXT,
    nm_ue TEXT,
    cd_municipio INTEGER,
    nm_municipio TEXT,
    nr_zona INTEGER,
    nr_secao INTEGER,
    cd_cargo INTEGER,
    ds_cargo TEXT,
    nr_votavel INTEGER,
    nm_votavel TEXT,
    qt_votos INTEGER,
    nr_local_votacao INTEGER,
    sq_candidato BIGINT,
    nm_local_votacao TEXT,
    ds_local_votacao_endereco TEXT
);

-- Índices de performance para buscas rápidas no aplicativo
CREATE INDEX IF NOT EXISTS idx_nm_votavel ON votacao_secao (nm_votavel);
CREATE INDEX IF NOT EXISTS idx_nm_municipio ON votacao_secao (nm_municipio);
CREATE INDEX IF NOT EXISTS idx_cd_cargo ON votacao_secao (cd_cargo);
