import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/votante.dart';
import '../../../core/supabase/supabase_provider.dart';

final votantesListProvider = FutureProvider<List<Votante>>((ref) async {
  final res = await supabase.from('votantes').select().order('nome');
  return (res as List).map((e) => Votante.fromJson(e as Map<String, dynamic>)).toList();
});
