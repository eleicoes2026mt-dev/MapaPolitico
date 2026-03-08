import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/tse_storage.dart';

final tseRowsProvider = StateNotifierProvider<TseRowsNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  return TseRowsNotifier();
});

class TseRowsNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
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

final tseNmVotavelSelectedProvider = StateNotifierProvider<TseNmVotavelNotifier, AsyncValue<String?>>((ref) {
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

/// Votos por município (NM_MUNICIPIO) para o candidato selecionado (NM_VOTAVEL).
/// Retorna Map<nomeMunicipio, qtVotos>.
final votosPorMunicipioTseProvider = Provider<AsyncValue<Map<String, int>>>((ref) {
  final rowsAsync = ref.watch(tseRowsProvider);
  final selectedAsync = ref.watch(tseNmVotavelSelectedProvider);
  if (rowsAsync is! AsyncData<List<Map<String, dynamic>>> ||
      selectedAsync is! AsyncData<String?>) {
    return const AsyncValue.data({});
  }
  final rows = rowsAsync.value;
  final selected = selectedAsync.value;
  if (selected == null || selected.isEmpty) return const AsyncValue.data({});
  final map = <String, int>{};
  for (final row in rows) {
    if (_getString(row, 'NM_VOTAVEL')?.trim() != selected.trim()) continue;
    final municipio = _getString(row, 'NM_MUNICIPIO')?.trim() ?? '';
    if (municipio.isEmpty) continue;
    final votos = _getInt(row, 'QT_VOTOS') ?? 0;
    map[municipio] = (map[municipio] ?? 0) + votos;
  }
  return AsyncValue.data(map);
});

String? _getString(Map<String, dynamic> row, String key) {
  final k = key.toUpperCase();
  for (final entry in row.entries) {
    if (entry.key.toString().toUpperCase() == k) {
      final v = entry.value;
      return v == null ? null : v.toString().trim();
    }
  }
  return null;
}

int? _getInt(Map<String, dynamic> row, String key) {
  final v = _getString(row, key);
  if (v == null) return null;
  return int.tryParse(v.replaceAll(RegExp(r'[^\d-]'), ''));
}
