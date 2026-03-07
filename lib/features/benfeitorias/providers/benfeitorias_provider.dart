import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/benfeitoria.dart';
import '../../../core/supabase/supabase_provider.dart';

final benfeitoriasListProvider = FutureProvider<List<Benfeitoria>>((ref) async {
  final res = await supabase.from('benfeitorias').select().order('data_realizacao', ascending: false);
  return (res as List).map((e) => Benfeitoria.fromJson(e as Map<String, dynamic>)).toList();
});
