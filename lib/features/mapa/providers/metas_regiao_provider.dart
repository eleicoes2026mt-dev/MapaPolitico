import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/candidato_campanha.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/metas_regiao_repository.dart';

final metasRegiaoCampanhaProvider =
    AsyncNotifierProvider<MetasRegiaoCampanhaNotifier, Map<String, int>>(MetasRegiaoCampanhaNotifier.new);

class MetasRegiaoCampanhaNotifier extends AsyncNotifier<Map<String, int>> {
  @override
  Future<Map<String, int>> build() async {
    final profile = ref.watch(profileProvider).valueOrNull;
    final cid = candidatoCampanhaProfileId(profile);
    if (cid == null) return {};
    return fetchMetasRegiao(cid);
  }

  Future<void> save(Map<String, int> metas) async {
    final profile = ref.read(profileProvider).valueOrNull;
    final cid = candidatoCampanhaProfileId(profile);
    if (cid == null) return;
    await saveMetasRegiao(cid, metas);
    state = AsyncData(await fetchMetasRegiao(cid));
  }
}
