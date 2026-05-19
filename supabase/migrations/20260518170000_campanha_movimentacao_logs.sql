-- Registros leves para manter atividade no projeto Supabase (máx. 2 automáticos/dia com 12 h entre eles + manual).

CREATE TABLE IF NOT EXISTS public.campanha_movimentacao_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  origem TEXT NOT NULL CHECK (origem IN ('manual', 'auto_app')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_campanha_movimentacao_profile_created
  ON public.campanha_movimentacao_logs (profile_id, created_at DESC);

COMMENT ON TABLE public.campanha_movimentacao_logs IS
  'Ping opcional do candidato para gerar tráfego no banco: até 2 registros automáticos por dia (12 h entre eles) ao abrir Configurações, ou registro manual.';

ALTER TABLE public.campanha_movimentacao_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS campanha_movimentacao_logs_select ON public.campanha_movimentacao_logs;
CREATE POLICY campanha_movimentacao_logs_select ON public.campanha_movimentacao_logs
  FOR SELECT TO authenticated
  USING (
    profile_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role::text = 'candidato'
    )
  );

DROP POLICY IF EXISTS campanha_movimentacao_logs_insert ON public.campanha_movimentacao_logs;
CREATE POLICY campanha_movimentacao_logs_insert ON public.campanha_movimentacao_logs
  FOR INSERT TO authenticated
  WITH CHECK (
    profile_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role::text = 'candidato'
    )
  );
