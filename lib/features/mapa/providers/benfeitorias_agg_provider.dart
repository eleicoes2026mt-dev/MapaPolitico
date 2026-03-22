import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../data/mt_municipios_coords.dart';

/// Linha agregada de benfeitorias por município (RPC `benfeitorias_agg_por_municipio`).
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

final benfeitoriasAggPorMunicipioProvider = FutureProvider<List<BenfeitoriaAggMunicipio>>((ref) async {
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
});
