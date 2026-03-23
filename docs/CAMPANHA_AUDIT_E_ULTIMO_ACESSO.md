# Auditoria da campanha e último acesso (menu)

## Migração

Aplicar `supabase/migrations/20250325120000_campanha_audit_e_ultimo_acesso.sql` (ou `supabase db push`).

Inclui:

- Colunas em `profiles`: `last_access_assessores_at`, `last_access_apoiadores_at`
- Tabela `campanha_audit_log` (insert/update/delete em assessores, apoiadores, votantes, benfeitorias)
- RPCs: `register_menu_access(p_menu)`, `restaurar_registro_audit(p_log_id)`

## App

- Ao abrir **Assessores** ou **Apoiadores**, chama `register_menu_access` e o menu mostra **Último acesso** nesses itens.
- **Configurações** (`/configuracoes`) aparece só para **candidato** (conta do deputado): lista de histórico, **Restaurar** (exclusões) e **Reverter edição** (volta ao `payload_before`).

## Restauração

- **Exclusão**: RPC `restaurar_registro_audit` reinsere a linha a partir do snapshot.
- **Edição**: atualização no cliente com os dados anteriores do log (pode falhar se houver FKs ou regras de negócio).

RLS: só o candidato dono da campanha lê `campanha_audit_log`.
