import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/benfeitoria.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../mapa/providers/benfeitorias_agg_provider.dart';
import '../../mapa/providers/benfeitorias_municipio_mapa_provider.dart';

final benfeitoriasListProvider = FutureProvider<List<Benfeitoria>>((ref) async {
  final res = await supabase.from('benfeitorias').select().order('data_realizacao', ascending: false);
  return (res as List).map((e) => Benfeitoria.fromJson(e as Map<String, dynamic>)).toList();
});

/// Benfeitorias de um apoiador (edição / detalhe).
final benfeitoriasPorApoiadorProvider = FutureProvider.family<List<Benfeitoria>, String>((ref, apoiadorId) async {
  final res = await supabase
      .from('benfeitorias')
      .select()
      .eq('apoiador_id', apoiadorId)
      .order('data_realizacao', ascending: false);
  return (res as List).map((e) => Benfeitoria.fromJson(e as Map<String, dynamic>)).toList();
});

void invalidateBenfeitoriasCaches(WidgetRef ref, {String? apoiadorId}) {
  ref.invalidate(benfeitoriasListProvider);
  ref.invalidate(benfeitoriasAggPorMunicipioProvider);
  ref.invalidate(benfeitoriasPorMunicipioMapaProvider);
  if (apoiadorId != null) {
    ref.invalidate(benfeitoriasPorApoiadorProvider(apoiadorId));
  }
}
