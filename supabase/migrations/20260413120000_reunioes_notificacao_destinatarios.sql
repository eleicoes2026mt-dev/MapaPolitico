-- Visitas "privadas": push e leitura só para perfis listados (quando visivel_apoiadores = false).

ALTER TABLE public.reunioes
  ADD COLUMN IF NOT EXISTS notificacao_profile_ids UUID[] NOT NULL DEFAULT '{}';

COMMENT ON COLUMN public.reunioes.notificacao_profile_ids IS
  'IDs em profiles (auth.uid) que recebem notificação e veem a visita quando não é visível para todos os apoiadores.';

CREATE INDEX IF NOT EXISTS idx_reunioes_notificacao_gin ON public.reunioes USING GIN (notificacao_profile_ids);

-- Antes: reunioes_read permitia SELECT em todas as linhas para qualquer autenticado.
DROP POLICY IF EXISTS "reunioes_read" ON public.reunioes;

-- Apoiador vê visita pública OU está na lista de destinatários.
CREATE POLICY "reunioes_apoiador_destinatario" ON public.reunioes
  FOR SELECT TO authenticated
  USING (auth.uid() = ANY (notificacao_profile_ids));
