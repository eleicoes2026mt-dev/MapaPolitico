import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../data/mt_municipios_coords.dart';

/// Linha agregada de benfeitorias por município.
class BenfeitoriaAggMunicipio {
  const BenfeitoriaAggMunicipio({
    required this.municipioId,
    required this.municipioNome,
    required this.qtd,
    required this.valorTotal,
  });

  final String municipioId;
  final String municipioNome;
  final int qtd;
  final double valorTotal;

  String get chaveNormalizada => normalizarNomeMunicipioMT(municipioNome);
}

Future<List<BenfeitoriaAggMunicipio>> _aggPorMunicipioViaCadastro() async {
  final munRes = await supabase.from('municipios').select('id, nome');
  final munById = <String, String>{};
  for (final raw in munRes as List) {
    final m = Map<String, dynamic>.from(raw as Map);
    final id = m['id']?.toString();
    final nome = m['nome']?.toString();
    if (id != null && nome != null && id.isNotEmpty) munById[id] = nome;
  }

  final benfRes = await supabase.from('benfeitorias').select('valor, municipio_id, apoiador_id');
  final benfList = benfRes as List;
  if (benfList.isEmpty) return [];

  final apoiadorIds = <String>{};
  for (final raw in benfList) {
    final row = Map<String, dynamic>.from(raw as Map);
    final aid = row['apoiador_id']?.toString();
    if (aid != null && aid.isNotEmpty) apoiadorIds.add(aid);
  }

  final apMunicipioPorId = <String, String?>{};
  if (apoiadorIds.isNotEmpty) {
    final ids = apoiadorIds.toList();
    final apRes = await supabase.from('apoiadores').select('id, municipio_id').inFilter('id', ids);
    for (final raw in apRes as List) {
      final m = Map<String, dynamic>.from(raw as Map);
      final id = m['id']?.toString();
      if (id == null) continue;
      apMunicipioPorId[id] = m['municipio_id']?.toString();
    }
  }

  final agg = <String, ({double v, int q})>{};
  for (final raw in benfList) {
    final row = Map<String, dynamic>.from(raw as Map);
    final valor = (row['valor'] as num?)?.toDouble() ?? 0.0;
    var mid = row['municipio_id']?.toString();
    if (mid == null || mid.isEmpty) {
      final aid = row['apoiador_id']?.toString();
      if (aid != null) mid = apMunicipioPorId[aid];
    }
    if (mid == null || mid.isEmpty) continue;

    final cur = agg[mid];
    agg[mid] = (v: (cur?.v ?? 0) + valor, q: (cur?.q ?? 0) + 1);
  }

  final out = <BenfeitoriaAggMunicipio>[];
  for (final e in agg.entries) {
    final nome = munById[e.key];
    if (nome == null) continue;
    out.add(BenfeitoriaAggMunicipio(
      municipioId: e.key,
      municipioNome: nome,
      qtd: e.value.q,
      valorTotal: e.value.v,
    ));
  }
  out.sort((a, b) => b.valorTotal.compareTo(a.valorTotal));
  return out;
}

Future<List<BenfeitoriaAggMunicipio>> _aggPorMunicipioViaRpc() async {
  final rows = await supabase.rpc('benfeitorias_agg_por_municipio');
  if (rows is! List) return [];
  final out = <BenfeitoriaAggMunicipio>[];
  for (final r in rows) {
    if (r is! Map) continue;
    final m = Map<String, dynamic>.from(r);
    final id = m['municipio_id']?.toString();
    final nome = m['municipio_nome']?.toString().trim() ?? '';
    if (id == null || id.isEmpty || nome.isEmpty) continue;
    final qtd = (m['qtd'] as num?)?.toInt() ?? 0;
    final valor = (m['valor_total'] as num?)?.toDouble() ?? 0.0;
    out.add(BenfeitoriaAggMunicipio(
      municipioId: id,
      municipioNome: nome,
      qtd: qtd,
      valorTotal: valor,
    ));
  }
  return out;
}

/// Agregação por município: soma no app usando município da benfeitoria ou do apoiador.
/// Se vier vazio, tenta a RPC (útil se políticas diferirem).
final benfeitoriasAggPorMunicipioProvider = FutureProvider<List<BenfeitoriaAggMunicipio>>((ref) async {
  try {
    final fromCadastro = await _aggPorMunicipioViaCadastro();
    if (fromCadastro.isNotEmpty) return fromCadastro;
  } catch (_) {}
  try {
    return await _aggPorMunicipioViaRpc();
  } catch (_) {
    return [];
  }
});
