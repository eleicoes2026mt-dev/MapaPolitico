import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../../models/movimentacao_log.dart';
import '../../auth/providers/auth_provider.dart';

final movimentacaoLogsListProvider = FutureProvider<List<MovimentacaoLog>>((ref) async {
  final profile = await ref.watch(profileProvider.future);
  if (profile == null || profile.role != 'candidato') {
    return const [];
  }
  final now = DateTime.now();
  final inicioPeriodoLocal = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 5));

  final res = await supabase
      .from('campanha_movimentacao_logs')
      .select()
      .eq('profile_id', profile.id)
      .gte('created_at', inicioPeriodoLocal.toUtc().toIso8601String())
      .order('created_at', ascending: false)
      .limit(100);
  return (res as List).map((e) => MovimentacaoLog.fromJson(Map<String, dynamic>.from(e as Map))).toList();
});

Future<void> insertMovimentacaoLog(WidgetRef ref, {required String origem}) async {
  final profile = await ref.read(profileProvider.future);
  if (profile == null || profile.role != 'candidato') {
    throw Exception('Apenas o candidato pode registrar.');
  }
  await supabase.from('campanha_movimentacao_logs').insert({
    'profile_id': profile.id,
    'origem': origem,
  });
  ref.invalidate(movimentacaoLogsListProvider);
}

/// Até 2 registros [auto_app] por dia (calendário local), com ≥12 h entre o 1.º e o 2.º.
/// Chamado ao abrir o cartão em Configurações.
Future<void> tryRegisterAutoMovimentacaoIfDue(WidgetRef ref) async {
  final profile = await ref.read(profileProvider.future);
  if (profile == null || profile.role != 'candidato') return;

  final uid = profile.id;
  final now = DateTime.now();
  final startLocal = DateTime(now.year, now.month, now.day);
  final endLocal = startLocal.add(const Duration(days: 1));

  final hoje = await supabase
      .from('campanha_movimentacao_logs')
      .select('created_at')
      .eq('profile_id', uid)
      .eq('origem', 'auto_app')
      .gte('created_at', startLocal.toUtc().toIso8601String())
      .lt('created_at', endLocal.toUtc().toIso8601String())
      .order('created_at', ascending: true);

  final rows = hoje as List;
  if (rows.length >= 2) return;

  if (rows.length == 1) {
    final primeiro = DateTime.parse(rows.first['created_at'].toString());
    if (now.difference(primeiro).inHours < 12) return;
  }

  await supabase.from('campanha_movimentacao_logs').insert({
    'profile_id': uid,
    'origem': 'auto_app',
  });
  ref.invalidate(movimentacaoLogsListProvider);
}
