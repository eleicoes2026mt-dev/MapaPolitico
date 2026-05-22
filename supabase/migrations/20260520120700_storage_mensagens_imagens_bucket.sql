-- Bucket público para imagens de mensagens: upload só sob pasta igual ao UUID do usuário (auth.uid()).
INSERT INTO storage.buckets (id, name, public)
VALUES ('mensagens', 'mensagens', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "mensagens_upload_pasta_uid" ON storage.objects;
CREATE POLICY "mensagens_upload_pasta_uid"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'mensagens'
    AND name LIKE (auth.uid())::text || '/%'
  );

DROP POLICY IF EXISTS "mensagens_update_pasta_uid" ON storage.objects;
CREATE POLICY "mensagens_update_pasta_uid"
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'mensagens'
    AND name LIKE (auth.uid())::text || '/%'
  )
  WITH CHECK (
    bucket_id = 'mensagens'
    AND name LIKE (auth.uid())::text || '/%'
  );

DROP POLICY IF EXISTS "mensagens_delete_pasta_uid" ON storage.objects;
CREATE POLICY "mensagens_delete_pasta_uid"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'mensagens'
    AND name LIKE (auth.uid())::text || '/%'
  );

-- Leitura pública do bucket de campanhas (URLs em imagem_url já expostas aos apoiadores).
DROP POLICY IF EXISTS "mensagens_leitura_publica" ON storage.objects;
CREATE POLICY "mensagens_leitura_publica"
  ON storage.objects FOR SELECT TO public
  USING (bucket_id = 'mensagens');
