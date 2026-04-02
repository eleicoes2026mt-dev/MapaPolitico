-- Armazena as subscrições push (Web Push API) dos usuários autenticados.
-- Usada pelo edge function "send-push" para enviar notificações.

CREATE TABLE push_subscriptions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id  UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  endpoint    TEXT NOT NULL,
  p256dh      TEXT NOT NULL,
  auth_key    TEXT NOT NULL,
  user_agent  TEXT,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE (profile_id, endpoint)
);

CREATE INDEX idx_push_sub_profile ON push_subscriptions(profile_id);

ALTER TABLE push_subscriptions ENABLE ROW LEVEL SECURITY;

-- Usuário só vê/gerencia suas próprias subscrições
CREATE POLICY "push_own" ON push_subscriptions
  FOR ALL TO authenticated
  USING (profile_id = auth.uid())
  WITH CHECK (profile_id = auth.uid());

-- Candidato pode enviar para todos (via edge function com service_role, não via RLS direto)
-- A edge function usa a service_role key e não depende de RLS.

COMMENT ON TABLE push_subscriptions IS
  'Subscrições Web Push (PWA). Usada pelo edge function send-push para notificar usuários.';
