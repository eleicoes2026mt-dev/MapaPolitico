-- Coluna opcional para URL pública de um PDF anexado à mensagem.
-- O arquivo é enviado ao mesmo bucket "mensagens" sob pasta uid/<id>.pdf.
ALTER TABLE public.mensagens
  ADD COLUMN IF NOT EXISTS pdf_url TEXT;

COMMENT ON COLUMN public.mensagens.pdf_url IS
  'URL pública do PDF anexado (Storage mensagens/<uid>/<id>.pdf). Opcional.';
