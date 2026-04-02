-- Apoiadores podem ler mensagens globais (notificações da campanha).
-- Usa a role diretamente para evitar dependência de auth.my_apoiador_id().
CREATE POLICY "mensagens_apoiador_read" ON mensagens
  FOR SELECT TO authenticated
  USING (escopo = 'global');
