-- Upsert em polos_regioes (ON CONFLICT DO UPDATE) exige UPDATE; sem isto o seed
-- client-side falha quando os 5 polos já existem e municipios está vazio.
-- Timestamp após 20260411160000 para não conflitar com histórico já aplicado no remoto.

DROP POLICY IF EXISTS "polos_regioes_update_auth" ON polos_regioes;
CREATE POLICY "polos_regioes_update_auth" ON polos_regioes
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
