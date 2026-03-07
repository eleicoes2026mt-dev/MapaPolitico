-- Bucket "avatars" e políticas para usuários autenticados poderem enviar foto de perfil

-- Cria o bucket "avatars" se não existir (público para exibir as fotos)
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Usuários autenticados podem fazer upload apenas do próprio arquivo (nome = uuid.ext)
CREATE POLICY "Usuários autenticados podem enviar avatar"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'avatars' AND name LIKE (auth.uid())::text || '.%');

-- Usuários autenticados podem atualizar o próprio arquivo (upsert)
CREATE POLICY "Usuários autenticados podem atualizar avatar"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'avatars' AND name LIKE (auth.uid())::text || '.%');

-- Leitura pública para avatars (bucket público)
CREATE POLICY "Avatar é público para leitura"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'avatars');
