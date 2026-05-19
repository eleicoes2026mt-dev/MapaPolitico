-- Link opcional (rede social, site) enviado com a mensagem / push
ALTER TABLE mensagens
  ADD COLUMN IF NOT EXISTS link_url TEXT;

COMMENT ON COLUMN mensagens.link_url IS 'URL pública (ex. Instagram) divulgada junto da mensagem; incluída no push quando preenchida.';
