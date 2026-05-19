# Último acesso (menu) e histórico de alterações (removido)

## Histórico de alterações (`campanha_audit_log`) — descontinuado

Para aliviar o banco e a interface, o **Registro de alterações** (auditoria, reverter edição, restaurar exclusões via log) foi **removido**.

- Migração que remove triggers, funções de log e a tabela: `supabase/migrations/20260518180000_remove_campanha_audit_log.sql`
- A função `restaurar_registro_audit` permanece no schema mas **só lança exceção** informando que o recurso foi descontinuado (evita chamadas antigas silenciosas).

Aplicar com `supabase db push` ou colar o SQL no Supabase SQL Editor no projeto correto.

## Último acesso nos menus (Assessores / Apoiadores)

Isto continua separado do histórico. A migração original `supabase/migrations/20250325120000_campanha_audit_e_ultimo_acesso.sql` (ou o estado atual após `db push`) define colunas em `profiles` como `last_access_assessores_at`, `last_access_apoiadores_at` e a RPC `register_menu_access(p_menu)`.

- Ao abrir **Assessores** ou **Apoiadores**, o app pode chamar `register_menu_access` e o menu mostra **Último acesso** nesses itens.

## Configurações

A tela **Configurações** continua disponível ao **candidato**, mas **sem** a lista de histórico de alterações.
