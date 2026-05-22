-- URL pública opcional para imagem anexa (enviada via Storage pela app).
ALTER TABLE public.mensagens
  ADD COLUMN IF NOT EXISTS imagem_url TEXT;

COMMENT ON COLUMN public.mensagens.imagem_url IS
  'Imagem opcional (JPEG em Storage bucket mensagens/<uid>/<msg_id>.jpg); exibida na lista com altura limitada.';
