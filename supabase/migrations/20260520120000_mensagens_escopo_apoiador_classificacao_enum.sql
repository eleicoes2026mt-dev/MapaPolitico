-- Novo escopo: mensagem só para apoiadores com a mesma classificação (coluna apoiadores.perfil).
-- Valor do enum numa migração separada (PostgreSQL: não usar o novo valor na mesma transação).

ALTER TYPE public.escopo_mensagem ADD VALUE 'apoiador_classificacao';
