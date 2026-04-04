-- Novos escopos para mensagens segmentadas.
-- IMPORTANTE: só ALTER TYPE neste ficheiro. O PostgreSQL (55P04) não permite usar
-- valores novos de enum na mesma transação em que foram criados; as políticas RLS
-- ficam na migração seguinte (20260413140100_*).

ALTER TYPE public.escopo_mensagem ADD VALUE 'privada_assessores';
ALTER TYPE public.escopo_mensagem ADD VALUE 'privada_apoiadores';
