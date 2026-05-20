-- Políticas RLS permissivas em SELECT são combinadas com OR.
-- Se a política legada «mensagens_read» (USING (true)) ainda existir após migrações
-- parciais, apoiadores/votantes passam a ver todas as linhas, inclusive privada_assessores.
DROP POLICY IF EXISTS "mensagens_read" ON public.mensagens;
