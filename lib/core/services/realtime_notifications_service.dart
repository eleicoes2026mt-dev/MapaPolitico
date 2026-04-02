import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_provider.dart';

/// Gerencia assinaturas Realtime do Supabase para notificações em tempo real.
/// Deve ser iniciado após o login e cancelado no logout.
class RealtimeNotificationsService {
  RealtimeNotificationsService._();
  static final instance = RealtimeNotificationsService._();

  RealtimeChannel? _channel;
  bool _iniciado = false;

  // Callbacks para exibir notificação in-app (snackbar/banner)
  void Function(String title, String body, String? url)? _onNotificacao;

  void setNotificacaoCallback(void Function(String, String, String?) cb) {
    _onNotificacao = cb;
  }

  /// Inicia o realtime sem ref — o callback notifica a UI; os providers são
  /// invalidados por quem criou o item (não há loop duplo).
  void initSimple() {
    if (_iniciado) return;
    _iniciado = true;

    _channel = supabase
        .channel('realtime-notificacoes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'mensagens',
          callback: (payload) {
            final data = payload.newRecord;
            final titulo = data['titulo'] as String? ?? 'Nova mensagem';
            final corpo = data['corpo'] as String? ?? '';
            _onNotificacao?.call(titulo, corpo, '/#/mensagens');
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'reunioes',
          callback: (payload) {
            final data = payload.newRecord;
            final titulo = data['titulo'] as String? ?? 'Nova visita agendada';
            final local = data['local_texto'] as String? ?? '';
            final body = local.isNotEmpty ? 'Local: $local' : 'Confira a agenda.';
            _onNotificacao?.call(titulo, body, '/#/agenda');
          },
        )
        .subscribe();
  }

  void init(Ref ref) => initSimple();

  void dispose() {
    _channel?.unsubscribe();
    _channel = null;
    _iniciado = false;
  }
}

/// Provider que ativa o serviço de notificações realtime quando logado.
final realtimeNotificacoesProvider = Provider<void>((ref) {
  RealtimeNotificationsService.instance.init(ref);
  ref.onDispose(() => RealtimeNotificationsService.instance.dispose());
});
