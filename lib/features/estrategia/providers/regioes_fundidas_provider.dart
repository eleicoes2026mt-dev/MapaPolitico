import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/regioes_fundidas.dart';

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

/// Regiões efetivas (fusões + regiões não fundidas) para uso em Metas, Responsáveis e mapa.
final regioesEfetivasProvider = Provider<List<RegiaoEfetiva>>((ref) {
  final state = ref.watch(regioesFundidasProvider).valueOrNull;
  final list = state?.list ?? [];
  return computeRegioesEfetivas(list);
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
