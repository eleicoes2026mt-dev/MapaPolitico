import '../../models/profile.dart';

/// UUID do perfil do candidato da campanha atual (painel do candidato ou assessor convidado).
String? candidatoCampanhaProfileId(Profile? profile) {
  if (profile == null) return null;
  if (profile.role == 'candidato') return profile.id;
  if (profile.role == 'assessor') {
    final b = profile.invitedBy?.trim();
    if (b != null && b.isNotEmpty) return b;
  }
  return null;
}
