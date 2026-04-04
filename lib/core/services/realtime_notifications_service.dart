import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/agenda/providers/agenda_provider.dart';
import '../../features/apoiadores/providers/apoiadores_provider.dart';
import '../../features/apoiadores/providers/campanha_kpis_provider.dart';
import '../../features/benfeitorias/providers/benfeitorias_provider.dart';
import '../../features/dashboard/providers/dashboard_provider.dart';
import '../../features/mensagens/providers/mensagens_provider.dart';
import '../../features/votantes/providers/votantes_provider.dart';
import '../supabase/supabase_provider.dart';

/// Gerencia assinaturas Realtime do Supabase: avisos in-app + atualização das listas.
class RealtimeNotificationsService {
  RealtimeNotificationsService._();
  static final instance = RealtimeNotificationsService._();

  RealtimeChannel? _channel;
  bool _iniciado = false;
  Ref? _ref;

  void Function(String title, String body, String? url)? _onNotificacao;

  void setNotificacaoCallback(void Function(String, String, String?) cb) {
    _onNotificacao = cb;
  }

  void _invalidateApoiadores() {
    final r = _ref;
    if (r == null) return;
    r.invalidate(apoiadoresListProvider);
    r.invalidate(campanhaKpisProvider);
    r.invalidate(aniversariantesProvider);
    r.invalidate(dashboardStatsProvider);
  }

  void _invalidateVotantes() {
    final r = _ref;
    if (r == null) return;
    r.invalidate(votantesListProvider);
    r.invalidate(dashboardStatsProvider);
    r.invalidate(campanhaKpisProvider);
  }

  void _invalidateBenfeitorias() {
    final r = _ref;
    if (r == null) return;
    r.invalidate(benfeitoriasListProvider);
  }

  void _invalidateMensagens() {
    final r = _ref;
    if (r == null) return;
    r.invalidate(mensagensListProvider);
  }

  void _invalidateReunioes() {
    final r = _ref;
    if (r == null) return;
    r.invalidate(visitasProvider);
    r.invalidate(todasVisitasProvider);
    r.invalidate(proximaVisitaMinhaCidadeProvider);
    r.invalidate(visitaPendenteConfirmacaoProvider);
  }

  /// Inicia o canal Realtime com [ref] para invalidar providers ao receber alterações.
  void init(Ref ref) {
    if (_iniciado) return;
    _ref = ref;
    _iniciado = true;

    var ch = supabase.channel('realtime-notificacoes');

    for (final ev in [
      PostgresChangeEvent.insert,
      PostgresChangeEvent.update,
      PostgresChangeEvent.delete,
    ]) {
      ch = ch.onPostgresChanges(
        event: ev,
        schema: 'public',
        table: 'apoiadores',
        callback: (_) => _invalidateApoiadores(),
      );
    }
    for (final ev in [
      PostgresChangeEvent.insert,
      PostgresChangeEvent.update,
      PostgresChangeEvent.delete,
    ]) {
      ch = ch.onPostgresChanges(
        event: ev,
        schema: 'public',
        table: 'votantes',
        callback: (_) => _invalidateVotantes(),
      );
    }
    for (final ev in [
      PostgresChangeEvent.insert,
      PostgresChangeEvent.update,
      PostgresChangeEvent.delete,
    ]) {
      ch = ch.onPostgresChanges(
        event: ev,
        schema: 'public',
        table: 'benfeitorias',
        callback: (_) => _invalidateBenfeitorias(),
      );
    }

    ch = ch
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'mensagens',
          callback: (payload) {
            _invalidateMensagens();
            final data = payload.newRecord;
            final titulo = data['titulo'] as String? ?? 'Nova mensagem';
            final corpo = data['corpo'] as String? ?? '';
            _onNotificacao?.call(titulo, corpo, '/#/mensagens');
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'mensagens',
          callback: (_) => _invalidateMensagens(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'mensagens',
          callback: (_) => _invalidateMensagens(),
        );

    ch = ch
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'reunioes',
          callback: (payload) {
            _invalidateReunioes();
            final data = payload.newRecord;
            final titulo = data['titulo'] as String? ?? 'Nova visita agendada';
            final local = data['local_texto'] as String? ?? '';
            final body = local.isNotEmpty ? 'Local: $local' : 'Confira a agenda.';
            _onNotificacao?.call(titulo, body, '/#/agenda');
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'reunioes',
          callback: (_) => _invalidateReunioes(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'reunioes',
          callback: (_) => _invalidateReunioes(),
        );

    _channel = ch.subscribe();
  }

  void dispose() {
    _channel?.unsubscribe();
    _channel = null;
    _iniciado = false;
    _ref = null;
  }
}

/// Provider que ativa o serviço de notificações realtime quando logado.
final realtimeNotificacoesProvider = Provider<void>((ref) {
  RealtimeNotificationsService.instance.init(ref);
  ref.onDispose(() => RealtimeNotificationsService.instance.dispose());
});
