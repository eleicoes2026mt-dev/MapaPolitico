-- Permissões SELECT permissivas combinam com OR: quem criou a linha
-- pode sempre lê-la (reforço quando políticas por papel falham ou mudam).
DROP POLICY IF EXISTS "mensagens_autor_read" ON public.mensagens;
CREATE POLICY "mensagens_autor_read" ON public.mensagens
  FOR SELECT TO authenticated
  USING (criado_por IS NOT NULL AND criado_por = auth.uid());

COMMENT ON POLICY "mensagens_autor_read" ON public.mensagens IS
  'O utilizador que criou a mensagem pode sempre consultá-la.';
