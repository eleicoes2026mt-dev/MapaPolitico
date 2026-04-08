import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/candidato_raiz_provider.dart';
import '../data/metas_regiao_repository.dart';

final metasRegiaoCampanhaProvider =
    AsyncNotifierProvider<MetasRegiaoCampanhaNotifier, Map<String, int>>(MetasRegiaoCampanhaNotifier.new);

class MetasRegiaoCampanhaNotifier extends AsyncNotifier<Map<String, int>> {
  @override
  Future<Map<String, int>> build() async {
    final cid = await ref.watch(candidatoRaizCampanhaProfileIdProvider.future);
    if (cid == null || cid.isEmpty) return {};
    return fetchMetasRegiao(cid);
  }

  Future<void> save(Map<String, int> metas) async {
    final cid = await ref.read(candidatoRaizCampanhaProfileIdProvider.future);
    if (cid == null || cid.isEmpty) return;
    await saveMetasRegiao(cid, metas);
    state = AsyncData(await fetchMetasRegiao(cid));
  }
}
