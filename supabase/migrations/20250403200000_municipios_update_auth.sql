-- Permite corrigir / alinhar cadastro de municípios pelo app (ex.: Araguanta → Araguainha, novos IBGE).
CREATE POLICY "municipios_update_auth" ON municipios
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
