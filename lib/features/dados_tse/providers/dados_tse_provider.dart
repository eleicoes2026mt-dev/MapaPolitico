import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/candidato_raiz_provider.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/tse_storage.dart';

final tseRowsProvider = StateNotifierProvider<TseRowsNotifier,
    AsyncValue<List<Map<String, dynamic>>>>((ref) {
  return TseRowsNotifier();
});

class TseRowsNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  TseRowsNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final rows = await TseStorage.loadRows();
      state = AsyncValue.data(rows);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setRows(List<Map<String, dynamic>> rows) async {
    await TseStorage.saveRows(rows);
    state = AsyncValue.data(rows);
  }

  /// Adiciona as linhas ao que já está salvo (não apaga dados existentes).
  Future<void> appendRows(List<Map<String, dynamic>> newRows) async {
    final current = state.valueOrNull ?? await TseStorage.loadRows();
    final combined = [...current, ...newRows];
    await TseStorage.saveRows(combined);
    state = AsyncValue.data(combined);
  }

  Future<void> clear() async {
    await TseStorage.saveRows([]);
    state = const AsyncValue.data([]);
  }
}

final tseNmVotavelSelectedProvider =
    StateNotifierProvider<TseNmVotavelNotifier, AsyncValue<String?>>((ref) {
  return TseNmVotavelNotifier();
});

class TseNmVotavelNotifier extends StateNotifier<AsyncValue<String?>> {
  TseNmVotavelNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final v = await TseStorage.loadNmVotavelSelected();
      state = AsyncValue.data(v);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setSelected(String? value) async {
    await TseStorage.saveNmVotavelSelected(value);
    state = AsyncValue.data(value);
  }
}

/// Lista de valores distintos da coluna NM_VOTAVEL (para o candidato escolher o seu nome).
final tseDistinctNmVotavelProvider = Provider<AsyncValue<List<String>>>((ref) {
  final rowsAsync = ref.watch(tseRowsProvider);
  return rowsAsync.when(
    data: (rows) {
      final set = <String>{};
      for (final row in rows) {
        final v = _getString(row, 'NM_VOTAVEL');
        if (v != null && v.trim().isNotEmpty) set.add(v.trim());
      }
      final list = set.toList()..sort();
      return AsyncValue.data(list);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Candidatos da eleição 2022 (MT) da tabela votacao_secao (view candidatos_2022_mt).
/// Para o candidato escolher "quem sou eu" no perfil.
final candidatos2022MtProvider =
    FutureProvider<List<({int sqCandidato, String nmVotavel})>>((ref) async {
  final res = await supabase
      .from('candidatos_2022_mt')
      .select('sq_candidato, nm_votavel')
      .order('nm_votavel');
  final list = <({int sqCandidato, String nmVotavel})>[];
  for (final e in res as List) {
    final map = e as Map<String, dynamic>;
    final sq = (map['sq_candidato'] as num?)?.toInt();
    final nm = map['nm_votavel']?.toString().trim() ?? '';
    if (sq != null && nm.isNotEmpty) list.add((sqCandidato: sq, nmVotavel: nm));
  }
  return list;
});

/// Votos por município na eleição 2022 para um candidato (sq_candidato) via RPC.
/// A agregação é feita no banco (SUM por nm_municipio), evitando o limite de ~1000 linhas
/// do Supabase e garantindo o total correto (ex.: 28.248 votos) e todas as cidades no mapa.
final votosPorMunicipioTseSupabaseProvider =
    FutureProvider.family<Map<String, int>, int>((ref, sqCandidato) async {
  final res = await supabase
      .rpc('get_votos_por_municipio', params: {'p_sq_candidato': sqCandidato});
  final map = <String, int>{};
  for (final e in res as List) {
    final row = e as Map<String, dynamic>;
    final municipio = row['nm_municipio']?.toString().trim() ?? '';
    if (municipio.isEmpty) continue;
    final qt = (row['qt_votos'] as num?)?.toInt() ?? 0;
    map[municipio] = qt;
  }
  return map;
});

/// sq_candidato TSE usado no mapa / ranking: perfil do deputado; assessor grau 1 via raiz da campanha.
final candidatoSqTse2022Provider = FutureProvider<int?>((ref) async {
  final p = ref.watch(profileProvider).valueOrNull;
  if (p == null) return null;
  if (p.role == 'candidato') return p.sqCandidatoTse2022;
  if (p.role == 'assessor') {
    final raiz = await ref.watch(candidatoRaizCampanhaProfileIdProvider.future);
    if (raiz == null || raiz.isEmpty) return null;
    try {
      final row = await supabase
          .from('profiles')
          .select('sq_candidato_tse_2022')
          .eq('id', raiz)
          .maybeSingle();
      return (row?['sq_candidato_tse_2022'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }
  return p.sqCandidatoTse2022;
});

/// Locais de votação (nome, endereço e quantidade de votos) por município via RPC.
/// Usa get_locais_votacao_por_municipio (agregação no banco + índice) para evitar timeout.
/// Filtra pelo mesmo candidato (sq_candidato_tse_2022) do perfil, para bater com o ranking e o mapa.
final locaisVotacaoPorMunicipioProvider = FutureProvider.family<
    List<({String nome, String? endereco, int votos})>,
    String>((ref, nomeMunicipio) async {
  if (nomeMunicipio.trim().isEmpty) return [];
  final sq = await ref.watch(candidatoSqTse2022Provider.future);
  final res = await supabase.rpc(
    'get_locais_votacao_por_municipio',
    params: {
      'p_nm_municipio': nomeMunicipio.trim(),
      'p_sq_candidato': sq,
    },
  );
  final rows = res as List;
  return rows
      .map((r) {
        final row = r as Map<String, dynamic>;
        final nome = row['nm_local_votacao']?.toString().trim() ?? '';
        final enderecoRaw = row['ds_local_votacao_endereco']?.toString().trim();
        final endereco =
            enderecoRaw == null || enderecoRaw.isEmpty ? null : enderecoRaw;
        final votos = (row['qt_votos'] as num?)?.toInt() ?? 0;
        return (nome: nome, endereco: endereco, votos: votos);
      })
      .where((e) => e.nome.isNotEmpty)
      .toList();
});

Map<String, int> _votosTseFromCsvMap(Ref ref) {
  final rowsAsync = ref.watch(tseRowsProvider);
  final selectedAsync = ref.watch(tseNmVotavelSelectedProvider);
  if (rowsAsync is! AsyncData<List<Map<String, dynamic>>> ||
      selectedAsync is! AsyncData<String?>) {
    return {};
  }
  final rows = rowsAsync.value;
  final selected = selectedAsync.value;
  if (selected == null || selected.isEmpty) return {};
  final map = <String, int>{};
  for (final row in rows) {
    if (_getString(row, 'NM_VOTAVEL')?.trim() != selected.trim()) continue;
    final municipio = _getString(row, 'NM_MUNICIPIO')?.trim() ?? '';
    if (municipio.isEmpty) continue;
    final votos = _getInt(row, 'QT_VOTOS') ?? 0;
    map[municipio] = (map[municipio] ?? 0) + votos;
  }
  return map;
}

/// Votos por município (NM_MUNICIPIO) para exibir no mapa.
/// [FutureProvider] linear: evita `ref.watch` condicional (assessor grau 1 não recebia TSE no ranking).
/// Usa Supabase quando há sq do candidato (deputado ou raiz para assessor); senão CSV local.
final votosPorMunicipioTseProvider =
    FutureProvider<Map<String, int>>((ref) async {
  final sq = await ref.watch(candidatoSqTse2022Provider.future);
  if (sq != null) {
    return ref.read(votosPorMunicipioTseSupabaseProvider(sq).future);
  }
  return _votosTseFromCsvMap(ref);
});

String? _getString(Map<String, dynamic> row, String key) {
  final k = key.toUpperCase();
  for (final entry in row.entries) {
    if (entry.key.toString().toUpperCase() == k) {
      final v = entry.value;
      return v?.toString().trim();
    }
  }
  return null;
}

int? _getInt(Map<String, dynamic> row, String key) {
  final v = _getString(row, key);
  if (v == null) return null;
  return int.tryParse(v.replaceAll(RegExp(r'[^\d-]'), ''));
}
