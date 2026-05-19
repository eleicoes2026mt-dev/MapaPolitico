-- Intervalo opcional de término da visita (agenda)
ALTER TABLE reunioes
  ADD COLUMN IF NOT EXISTS data_reuniao_fim DATE,
  ADD COLUMN IF NOT EXISTS hora_fim TIME;

COMMENT ON COLUMN reunioes.data_reuniao_fim IS 'Data final do período da visita; NULL = só o dia de data_reuniao.';
COMMENT ON COLUMN reunioes.hora_fim IS 'Hora final (opcional); NULL = sem horário específico de término.';
