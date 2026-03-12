import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../data/mt_municipios_coords.dart';

/// Estimativa de votos por cidade (chave normalizada para bater com TSE).
/// Soma: apoiadores.estimativa_votos (por cidade_nome) + votantes.qtd_votos_familia (por municipio_id → nome).
final estimativaPorCidadeProvider = FutureProvider<Map<String, int>>((ref) async {
  final client = supabase;
  final result = <String, int>{};

  // Apoiadores: cidade_nome + estimativa_votos
  final apoiadoresRes = await client.from('apoiadores').select('cidade_nome, estimativa_votos');
  for (final r in apoiadoresRes as List) {
    final row = r as Map<String, dynamic>;
    final nome = row['cidade_nome']?.toString().trim();
    if (nome == null || nome.isEmpty) continue;
    final key = normalizarNomeMunicipioMT(nome);
    final qt = (row['estimativa_votos'] as num?)?.toInt() ?? 0;
    result[key] = (result[key] ?? 0) + qt;
  }

  // Votantes: municipio_id + qtd_votos_familia; resolver nome do município
  final votantesRes = await client.from('votantes').select('municipio_id, qtd_votos_familia');
  final municipioIds = <String>{};
  for (final r in votantesRes as List) {
    final row = r as Map<String, dynamic>;
    final mid = row['municipio_id']?.toString().trim();
    if (mid != null && mid.isNotEmpty) municipioIds.add(mid);
  }

  final idToNome = <String, String>{};
  for (final id in municipioIds) {
    final res = await client.from('municipios').select('nome').eq('id', id).maybeSingle();
    final nome = res?['nome']?.toString().trim() ?? '';
    if (nome.isNotEmpty) idToNome[id] = nome;
  }

  for (final r in votantesRes as List) {
    final row = r as Map<String, dynamic>;
    final mid = row['municipio_id']?.toString().trim();
    if (mid == null || mid.isEmpty) continue;
    final nome = idToNome[mid];
    if (nome == null || nome.isEmpty) continue;
    final key = normalizarNomeMunicipioMT(nome);
    final qt = (row['qtd_votos_familia'] as num?)?.toInt() ?? 1;
    result[key] = (result[key] ?? 0) + qt;
  }

  return result;
});
