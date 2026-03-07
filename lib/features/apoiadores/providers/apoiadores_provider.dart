import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/apoiador.dart';
import '../../../core/supabase/supabase_provider.dart';

final apoiadoresListProvider = FutureProvider<List<Apoiador>>((ref) async {
  final res = await supabase.from('apoiadores').select().order('nome');
  return (res as List).map((e) => Apoiador.fromJson(e as Map<String, dynamic>)).toList();
});
