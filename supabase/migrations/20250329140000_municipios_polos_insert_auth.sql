-- Permite que usuários autenticados insiram dados de referência (polos e municípios).
-- Necessário para o seed automático client-side quando migrations não foram aplicadas.
CREATE POLICY "polos_regioes_insert_auth" ON polos_regioes
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "municipios_insert_auth" ON municipios
  FOR INSERT TO authenticated WITH CHECK (true);
