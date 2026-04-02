-- Estende a tabela reunioes para suportar visitas agendadas do deputado às cidades.

ALTER TABLE reunioes
  ADD COLUMN IF NOT EXISTS municipio_id  UUID REFERENCES municipios(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS descricao     TEXT,
  ADD COLUMN IF NOT EXISTS notificados_em TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS visivel_apoiadores BOOLEAN NOT NULL DEFAULT true;

CREATE INDEX IF NOT EXISTS idx_reunioes_municipio ON reunioes(municipio_id);
CREATE INDEX IF NOT EXISTS idx_reunioes_visivel ON reunioes(visivel_apoiadores, data_reuniao);

-- Qualquer usuário autenticado pode ler reuniões visíveis para apoiadores.
-- A filtragem por cidade (municipio_id) é feita no app.
DROP POLICY IF EXISTS "reunioes_apoiador_visivel" ON reunioes;
CREATE POLICY "reunioes_apoiador_visivel" ON reunioes
  FOR SELECT TO authenticated
  USING (visivel_apoiadores = true);

COMMENT ON COLUMN reunioes.municipio_id       IS 'Cidade da visita (FK municipios).';
COMMENT ON COLUMN reunioes.descricao          IS 'Informações extras: local, horário, agenda do dia.';
COMMENT ON COLUMN reunioes.notificados_em     IS 'Timestamp do último envio de push para este evento.';
COMMENT ON COLUMN reunioes.visivel_apoiadores IS 'Se true, apoiadores da cidade verão o aviso de visita.';
