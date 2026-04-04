-- Origem do cadastro (QR «Amigos do Gilberto») para cor no mapa e relatórios.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS cadastro_via_qr BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN public.profiles.cadastro_via_qr IS
  'True se o utilizador criou conta pelo link/QR público (metadata no signup).';

ALTER TABLE public.votantes
  ADD COLUMN IF NOT EXISTS cadastro_via_qr BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN public.votantes.cadastro_via_qr IS
  'True se o registro veio do fluxo QR / Amigos do Gilberto (copiado do perfil ou gravação direta).';
