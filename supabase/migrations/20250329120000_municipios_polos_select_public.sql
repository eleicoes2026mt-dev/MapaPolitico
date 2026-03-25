-- Catálogo de polos/municípios é dado de referência (sem dados sensíveis).
-- Permite SELECT para o role anon para que o cliente sempre receba linhas quando a tabela
-- estiver populada (antes só «authenticated» tinha política; sessões sem JWT válido viam 0 linhas).

CREATE POLICY "municipios_select_anon" ON municipios FOR SELECT TO anon USING (true);
CREATE POLICY "polos_regioes_select_anon" ON polos_regioes FOR SELECT TO anon USING (true);
