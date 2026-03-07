import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_provider.dart';

final mensagensCountProvider = FutureProvider<int>((ref) async {
  final res = await supabase.from('mensagens').select('id');
  return res.length;
});
