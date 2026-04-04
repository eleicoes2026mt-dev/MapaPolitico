import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../../models/benfeitoria.dart';
import '../data/mt_municipios_coords.dart';

/// Uma benfeitoria no mapa com dados do apoiador vinculado (cadastro na campanha).
class BenfeitoriaMapaItem {
  const BenfeitoriaMapaItem({
    required this.benfeitoria,
    required this.apoiadorNome,
    this.apoiadorTelefone,
    this.apoiadorEmail,
    this.apoiadorTipo,
    this.apoiadorCidadeNome,
  });

  final Benfeitoria benfeitoria;
  final String apoiadorNome;
  final String? apoiadorTelefone;
  final String? apoiadorEmail;
  final String? apoiadorTipo;
  final String? apoiadorCidadeNome;
}

/// Benfeitorias cuja localização no mapa cai neste município (município da linha ou do apoiador).
/// [municipioChaveOuNome] pode ser chave normalizada (lista do ranking) ou nome — comparação sempre normalizada.
final benfeitoriasPorMunicipioMapaProvider =
    FutureProvider.autoDispose.family<List<BenfeitoriaMapaItem>, String>((ref, municipioChaveOuNome) async {
  final alvo = normalizarNomeMunicipioMT(municipioChaveOuNome);
  if (alvo.isEmpty) return [];

  final munRes = await supabase.from('municipios').select('id, nome');
  final munById = <String, String>{};
  for (final raw in munRes as List) {
    final m = Map<String, dynamic>.from(raw as Map);
    final id = m['id']?.toString();
    final nome = m['nome']?.toString();
    if (id != null && nome != null && id.isNotEmpty) munById[id] = nome;
  }

  final benfRes = await supabase.from('benfeitorias').select(
        'id, apoiador_id, municipio_id, titulo, descricao, valor, data_realizacao, tipo, status, foto_url, '
        'apoiadores(nome, telefone, email, tipo, cidade_nome, municipio_id)',
      );
  final out = <BenfeitoriaMapaItem>[];

  for (final raw in benfRes as List) {
    final m = Map<String, dynamic>.from(raw as Map);
    final apRaw = m.remove('apoiadores');
    final apMap = apRaw is Map ? Map<String, dynamic>.from(apRaw) : <String, dynamic>{};

    String? mid = m['municipio_id']?.toString();
    if (mid == null || mid.isEmpty) {
      mid = apMap['municipio_id']?.toString();
    }
    if (mid == null || mid.isEmpty) continue;

    final nomeMun = munById[mid];
    if (nomeMun == null) continue;
    if (normalizarNomeMunicipioMT(nomeMun) != alvo) continue;

    final b = Benfeitoria.fromJson(m);
    final nomeAp = apMap['nome']?.toString().trim() ?? '—';
    out.add(BenfeitoriaMapaItem(
      benfeitoria: b,
      apoiadorNome: nomeAp,
      apoiadorTelefone: apMap['telefone']?.toString().trim(),
      apoiadorEmail: apMap['email']?.toString().trim(),
      apoiadorTipo: apMap['tipo']?.toString().trim(),
      apoiadorCidadeNome: apMap['cidade_nome']?.toString().trim(),
    ));
  }

  out.sort((a, b) {
    final da = a.benfeitoria.dataRealizacao;
    final db = b.benfeitoria.dataRealizacao;
    if (da != null && db != null && da != db) return db.compareTo(da);
    if (da != null && db == null) return -1;
    if (da == null && db != null) return 1;
    return b.benfeitoria.valor.compareTo(a.benfeitoria.valor);
  });

  return out;
});
