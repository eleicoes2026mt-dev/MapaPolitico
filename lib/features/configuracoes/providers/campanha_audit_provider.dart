import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../models/campanha_audit_log.dart';
import '../../apoiadores/providers/apoiadores_provider.dart';
import '../../assessores/providers/assessores_provider.dart';
import '../../benfeitorias/providers/benfeitorias_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../mapa/providers/estimativa_por_cidade_provider.dart';
import '../../votantes/providers/votantes_provider.dart';

/// Histórico de alterações (apenas candidato; RLS no Supabase).
final campanhaAuditLogProvider = FutureProvider.autoDispose<List<CampanhaAuditLog>>((ref) async {
  final client = supabase;
  try {
    final res = await client
        .from('campanha_audit_log')
        .select()
        .order('created_at', ascending: false)
        .limit(300);
    final list = res as List;
    return list.map((e) => CampanhaAuditLog.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  } catch (e) {
    final s = e.toString();
    if (s.contains('PGRST205') ||
        s.contains('campanha_audit_log') && s.contains('Could not find the table')) {
      throw Exception(
        'A tabela de auditoria ainda não existe neste projeto Supabase. '
        'No dashboard: SQL → cole e execute o ficheiro '
        'supabase/migrations/20250325120000_campanha_audit_e_ultimo_acesso.sql '
        '(ou rode: supabase db push). Depois recarregue esta página.',
      );
    }
    rethrow;
  }
});

Future<void> restaurarExclusaoAudit(WidgetRef ref, String logId) async {
  await supabase.rpc('restaurar_registro_audit', params: {'p_log_id': logId});
  _invalidateCampanha(ref);
}

/// Reverte uma edição ao estado [payload_before] do log.
Future<void> reverterEdicaoAudit(WidgetRef ref, CampanhaAuditLog log) async {
  if (log.action != 'update' || log.payloadBefore == null) {
    throw Exception('Este log não é uma edição reversível.');
  }
  final table = log.tableName;
  final before = Map<String, dynamic>.from(log.payloadBefore!);
  final id = before['id']?.toString();
  if (id == null || id.isEmpty) {
    throw Exception('ID ausente no histórico.');
  }
  final patch = Map<String, dynamic>.from(before);
  patch.remove('id');
  patch.remove('created_at');
  await supabase.from(table).update(patch).eq('id', id);
  _invalidateCampanha(ref);
}

void _invalidateCampanha(WidgetRef ref) {
  ref.invalidate(campanhaAuditLogProvider);
  ref.invalidate(apoiadoresListProvider);
  ref.invalidate(assessoresListProvider);
  ref.invalidate(votantesListProvider);
  ref.invalidate(benfeitoriasListProvider);
  ref.invalidate(dashboardStatsProvider);
  ref.invalidate(estimativaPorCidadeProvider);
}
