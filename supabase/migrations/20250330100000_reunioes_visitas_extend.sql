-- Estende a tabela reunioes para suportar visitas agendadas do deputado às cidades.

ALTER TABLE reunioes
  ADD COLUMN IF NOT EXISTS municipio_id  UUID REFERENCES municipios(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS descricao     TEXT,
  ADD COLUMN IF NOT EXISTS notificados_em TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS visivel_apoiadores BOOLEAN NOT NULL DEFAULT true;

CREATE INDEX IF NOT EXISTS idx_reunioes_municipio ON reunioes(municipio_id);
CREATE INDEX IF NOT EXISTS idx_reunioes_visivel ON reunioes(visivel_apoiadores, data_reuniao);

-- Apoiadores podem ler visitas marcadas como visíveis para a cidade deles.
-- (Filtragem extra por municipio_id é feita no app; a RLS permite ler qualquer
--  reunião visível para não criar dependência de join complexo aqui.)
CREATE POLICY "reunioes_apoiador_visivel" ON reunioes
  FOR SELECT TO authenticated
  USING (
    visivel_apoiadores = true
    AND auth.my_assessor_id() IS NOT NULL  -- só quem é apoiador tem assessor_id
  );

COMMENT ON COLUMN reunioes.municipio_id       IS 'Cidade da visita (FK municipios).';
COMMENT ON COLUMN reunioes.descricao          IS 'Informações extras: local, horário, agenda do dia.';
COMMENT ON COLUMN reunioes.notificados_em     IS 'Timestamp do último envio de push para este evento.';
COMMENT ON COLUMN reunioes.visivel_apoiadores IS 'Se true, apoiadores da cidade verão o aviso de visita.';
