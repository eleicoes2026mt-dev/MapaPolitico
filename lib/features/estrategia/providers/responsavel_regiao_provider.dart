import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_provider.dart';

/// Mapa regiao_id (RegiaoEfetiva.id) -> assessor_id (UUID) ou null (sem responsável).
final responsavelRegiaoProvider =
    AsyncNotifierProvider<ResponsavelRegiaoNotifier, Map<String, String?>>(ResponsavelRegiaoNotifier.new);

class ResponsavelRegiaoNotifier extends AsyncNotifier<Map<String, String?>> {
  @override
  Future<Map<String, String?>> build() async {
    final res = await supabase.from('responsavel_regiao').select('regiao_id, assessor_id');
    final map = <String, String?>{};
    for (final row in res as List) {
      final r = row as Map<String, dynamic>;
      map[r['regiao_id'] as String] = r['assessor_id'] as String?;
    }
    return map;
  }

  void setResponsavel(String regiaoId, String? assessorId) {
    final current = state.valueOrNull ?? {};
    state = AsyncData(Map<String, String?>.from(current)..[regiaoId] = assessorId);
  }

  Future<void> save(Map<String, String?> desired) async {
    final current = await supabase.from('responsavel_regiao').select('regiao_id, assessor_id');
    final existing = <String, String>{};
    for (final row in current as List) {
      final r = row as Map<String, dynamic>;
      existing[r['regiao_id'] as String] = r['assessor_id'] as String;
    }
    for (final e in desired.entries) {
      final regiaoId = e.key;
      final assessorId = e.value;
      if (assessorId == null || assessorId.isEmpty) {
        if (existing.containsKey(regiaoId)) {
          await supabase.from('responsavel_regiao').delete().eq('regiao_id', regiaoId);
        }
      } else {
        await supabase.from('responsavel_regiao').upsert(
          {'regiao_id': regiaoId, 'assessor_id': assessorId},
          onConflict: 'regiao_id',
        );
      }
    }
    state = AsyncData(Map<String, String?>.from(desired));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await build());
  }
}
