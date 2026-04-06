import '../../../core/supabase/supabase_provider.dart';

Future<Map<String, int>> fetchMetasRegiao(String candidatoProfileId) async {
  final res = await supabase
      .from('campanha_metas_regiao')
      .select('cd_rgint, meta_votos')
      .eq('candidato_profile_id', candidatoProfileId);
  final map = <String, int>{};
  for (final row in res as List) {
    final r = row as Map<String, dynamic>;
    final k = r['cd_rgint']?.toString();
    final v = r['meta_votos'];
    if (k == null || k.isEmpty) continue;
    if (v is int) {
      map[k] = v;
    } else if (v is num) {
      map[k] = v.toInt();
    }
  }
  return map;
}

/// Grava metas (>0). Regiões com 0 ou ausentes são removidas da tabela.
Future<void> saveMetasRegiao(String candidatoProfileId, Map<String, int> metas) async {
  final desired = <String, int>{};
  for (final e in metas.entries) {
    if (e.value > 0) desired[e.key] = e.value;
  }
  final existing = await fetchMetasRegiao(candidatoProfileId);
  for (final k in existing.keys) {
    if (!desired.containsKey(k)) {
      await supabase
          .from('campanha_metas_regiao')
          .delete()
          .eq('candidato_profile_id', candidatoProfileId)
          .eq('cd_rgint', k);
    }
  }
  for (final e in desired.entries) {
    await supabase.from('campanha_metas_regiao').upsert(
      {
        'candidato_profile_id': candidatoProfileId,
        'cd_rgint': e.key,
        'meta_votos': e.value,
      },
      onConflict: 'candidato_profile_id,cd_rgint',
    );
  }
}
