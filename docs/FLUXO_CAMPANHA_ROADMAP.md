# Fluxo da campanha (roadmap)

## Hierarquia desejada

1. **Candidato / Deputado** — visão global, convida assessores, mensagens para a campanha ou por região/cidade.
2. **Assessor** — painel da campanha, convida apoiadores, pode agir em nome do candidato (conforme regras).
3. **Apoiador** — perfil por vínculo à campanha (e à sua base/cidade), cadastra **votantes sem login** (apenas registro).
4. **Votante** — dado no banco (nome, cidade, votos estimados); **sem conta** no app.

O app já cobre boa parte: convite assessor/apoiador, RLS por papel, votantes sem auth. Falta evoluir **mensagens segmentadas** e **notificações push**.

## Erro ao clicar em «Aceitar convite» (web)

- Mensagem `otp_expired` / link inválido: o convite do Supabase **expira** (prazo curto). Solução operacional: **Reenviar convite** no painel e usar o link novo de imediato.
- O app agora **lê o `#fragmento`**, trata erro **antes** do GoRouter e redireciona para **Login** com texto em português (em vez de «Page Not Found»).

## Próximos passos sugeridos (mensagens e reuniões)

- **Mensagens por cidade**: modelo de dados ligando `mensagens` (ou nova tabela) a `municipio_id` ou nome normalizado; filtro «apoiadores de Alta Floresta» para destinatários lógicos.
- **Permissões**: candidato e assessor criam convite de reunião; apoiadores da cidade recebem no app.
- **Notificações**:
  - Curto prazo: **in-app** (badge + lista ao abrir) usando tabela `notificacoes` + Realtime ou poll.
  - Médio prazo: **push** (FCM) com token por `profiles` e Edge Function ou trigger.
- **Endereço e data**: campos em `mensagens` ou entidade `reunioes` (já existe esboço no projeto) + UI no painel do candidato/assessor.

Este documento é um guia de produto; implementação pode ser feita em fases.
