import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../supabase/supabase_provider.dart';
import '../utils/candidato_campanha.dart';
import '../../features/auth/providers/auth_provider.dart';

/// UUID do perfil do candidato (deputado) na campanha — alinhado a `public.app_candidato_raiz_campanha()` no Supabase.
/// Assessores grau 1 precisam disto quando `invited_by` está vazio ou em cadeia.
final candidatoRaizCampanhaProfileIdProvider = FutureProvider<String?>((ref) async {
  final profile = ref.watch(profileProvider).valueOrNull;
  if (profile == null) return null;
  if (profile.role == 'candidato') return profile.id;
  if (profile.role != 'assessor') return null;
  try {
    final raw = await supabase.rpc('app_candidato_raiz_campanha');
    if (raw != null) {
      final s = raw.toString().trim();
      if (s.isNotEmpty) return s;
    }
  } catch (_) {}
  return candidatoCampanhaProfileId(profile);
});
