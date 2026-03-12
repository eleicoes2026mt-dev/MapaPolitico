import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/regioes_fundidas.dart';
import '../../../core/constants/regioes_mt.dart';
import '../../auth/providers/auth_provider.dart';
import '../../mapa/data/geo_loader.dart';
import '../data/mapa_custom_repository.dart';

/// Estado exposto: lista atual + quantidade de ações que podem ser desfeitas.
class RegioesFundidasState {
  const RegioesFundidasState({required this.list, this.undoCount = 0});
  final List<RegiaoFundida> list;
  final int undoCount;
}

final regioesFundidasProvider = AsyncNotifierProvider<RegioesFundidasNotifier, RegioesFundidasState>(RegioesFundidasNotifier.new);

class RegioesFundidasNotifier extends AsyncNotifier<RegioesFundidasState> {
  final List<List<RegiaoFundida>> _undoStack = [];
  static const int _maxUndo = 30;

  @override
  Future<RegioesFundidasState> build() async {
    final list = await loadRegioesFundidas();
    return RegioesFundidasState(list: list);
  }

  Future<void> add(RegiaoFundida fundida) async {
    state = const AsyncLoading();
    final list = await loadRegioesFundidas();
    if (list.any((e) => e.id == fundida.id)) {
      state = AsyncData(RegioesFundidasState(list: list, undoCount: _undoStack.length));
      return;
    }
    _pushUndo(list);
    final newList = [...list, fundida];
    await saveRegioesFundidas(newList);
    state = AsyncData(RegioesFundidasState(list: newList, undoCount: _undoStack.length));
  }

  Future<void> remove(String id) async {
    state = const AsyncLoading();
    final list = await loadRegioesFundidas();
    _pushUndo(list);
    final newList = list.where((e) => e.id != id).toList();
    await saveRegioesFundidas(newList);
    state = AsyncData(RegioesFundidasState(list: newList, undoCount: _undoStack.length));
  }

  /// Atualiza o nome de uma região fundida (reflete em Metas, Responsáveis, Regiões e mapa).
  Future<void> updateNome(String fundidaId, String nome) async {
    final trimmed = nome.trim();
    if (trimmed.isEmpty) return;
    state = const AsyncLoading();
    final list = await loadRegioesFundidas();
    _pushUndo(list);
    final newList = list.map((f) => f.id == fundidaId ? RegiaoFundida(id: f.id, nome: trimmed, ids: f.ids) : f).toList();
    await saveRegioesFundidas(newList);
    state = AsyncData(RegioesFundidasState(list: newList, undoCount: _undoStack.length));
  }

  /// Remove uma região de sua fusão (para que nome/cor valham só para essa região).
  /// Se a fusão ficar com 0 regiões, remove a fusão; se ficar com 1, remove a fusão e a região volta a ser independente.
  Future<void> removeCdRgintFromFusion(String cdRgint) async {
    state = const AsyncLoading();
    final list = await loadRegioesFundidas();
    _pushUndo(list);
    final newList = <RegiaoFundida>[];
    for (final f in list) {
      if (!f.ids.contains(cdRgint)) {
        newList.add(f);
        continue;
      }
      final newIds = f.ids.where((id) => id != cdRgint).toList();
      if (newIds.length >= 2) {
        newList.add(RegiaoFundida(id: f.id, nome: f.nome, ids: newIds));
      }
      // se newIds.length <= 1, não readiciona a fusão (região fica sozinha ou fusão some)
    }
    await saveRegioesFundidas(newList);
    state = AsyncData(RegioesFundidasState(list: newList, undoCount: _undoStack.length));
  }

  void _pushUndo(List<RegiaoFundida> snapshot) {
    _undoStack.add(List.from(snapshot));
    if (_undoStack.length > _maxUndo) _undoStack.removeAt(0);
  }

  Future<bool> undo() async {
    if (_undoStack.isEmpty) return false;
    state = const AsyncLoading();
    final previous = _undoStack.removeLast();
    await saveRegioesFundidas(previous);
    state = AsyncData(RegioesFundidasState(list: previous, undoCount: _undoStack.length));
    return true;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final list = await loadRegioesFundidas();
    state = AsyncData(RegioesFundidasState(list: list, undoCount: _undoStack.length));
  }
}

/// Única fonte de regiões: GeoJSON MT_RG_Imediatas_2024 (assets/geo/mt_regioes_imediatas_2024.geojson).
/// Mapas, Metas, Responsáveis e Regiões exibem APENAS as regiões deste arquivo.
final regioesMapeadasMTProvider = FutureProvider<List<RegiaoMT>>((ref) async {
  try {
    final list = await loadRegioesImediatasMTFromAsset(kMTRegioesImediatas2024Asset);
    return list.asMap().entries.map((e) {
      final r = e.value;
      final idx = e.key;
      final base = regioesIntermediariasMT.where((b) => b.id == r.cdRgint).firstOrNull;
      return RegiaoMT(
        id: r.id,
        nome: r.nome,
        descricao: base?.descricao ?? (r.cdRgint ?? ''),
        cor: base?.cor ?? Colors.grey,
        ordem: base?.ordem ?? idx,
      );
    }).toList();
  } catch (_) {
    return [];
  }
});

/// Regiões efetivas (fusões + regiões não fundidas + nomes customizados). Apenas regiões do GeoJSON 2024.
final regioesEfetivasProvider = Provider<List<RegiaoEfetiva>>((ref) {
  final state = ref.watch(regioesFundidasProvider).valueOrNull;
  final list = state?.list ?? [];
  final nomes = ref.watch(nomesCustomizadosProvider).valueOrNull ?? {};
  final base = ref.watch(regioesMapeadasMTProvider).valueOrNull ?? [];
  return computeRegioesEfetivas(list, baseRegioes: base, nomesCustomizados: nomes);
});

/// True apenas para usuários com role 'admin'. Edição de regiões (nome, fundir) fica restrita a administrador.
final isAdminProvider = Provider<bool>((ref) {
  final profile = ref.watch(profileProvider).valueOrNull;
  return profile?.role == 'admin';
});

/// Lista de fusões para o mapa (resolver nome por cdRgint).
final regioesFundidasParaMapaProvider = Provider<List<RegiaoFundida>>((ref) {
  final state = ref.watch(regioesFundidasProvider).valueOrNull;
  return state?.list ?? [];
});

/// Se há ações que podem ser desfeitas.
final canUndoRegioesFundidasProvider = Provider<bool>((ref) {
  final state = ref.watch(regioesFundidasProvider).valueOrNull;
  return (state?.undoCount ?? 0) > 0;
});

/// Nomes customizados por cdRgint (editados no mapa); persistidos no Supabase para todos os usuários.
final nomesCustomizadosProvider =
    AsyncNotifierProvider<NomesCustomizadosNotifier, Map<String, String>>(NomesCustomizadosNotifier.new);

class NomesCustomizadosNotifier extends AsyncNotifier<Map<String, String>> {
  @override
  Future<Map<String, String>> build() async {
    return await loadNomesCustomizadosFromSupabase();
  }

  Future<void> setNome(String cdRgint, String nome) async {
    await saveNomeToSupabase(cdRgint, nome);
    final map = Map<String, String>.from(state.valueOrNull ?? {});
    final trimmed = nome.trim();
    if (trimmed.isEmpty) {
      map.remove(cdRgint);
    } else {
      map[cdRgint] = trimmed;
    }
    state = AsyncData(map);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await loadNomesCustomizadosFromSupabase());
  }

  /// Restaura todos os nomes para o padrão do mapa (GeoJSON). Após isso, mapa e outras telas exibem só os nomes padrão.
  Future<void> restoreNomesPadrao() async {
    await clearAllNomesCustomizadosInSupabase();
    await refresh();
  }
}

/// Cores customizadas por cdRgint (hex "#RRGGBB"); persistidas no Supabase para todos os usuários.
final coresCustomizadasProvider =
    AsyncNotifierProvider<CoresCustomizadasNotifier, Map<String, String>>(CoresCustomizadasNotifier.new);

class CoresCustomizadasNotifier extends AsyncNotifier<Map<String, String>> {
  @override
  Future<Map<String, String>> build() async {
    return await loadCoresCustomizadasFromSupabase();
  }

  Future<void> setCor(String cdRgint, String hexColor) async {
    await saveCorToSupabase(cdRgint, hexColor);
    final map = Map<String, String>.from(state.valueOrNull ?? {});
    final trimmed = hexColor.trim();
    if (trimmed.isEmpty) {
      map.remove(cdRgint);
    } else {
      map[cdRgint] = trimmed;
    }
    state = AsyncData(map);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await loadCoresCustomizadasFromSupabase());
  }
}
