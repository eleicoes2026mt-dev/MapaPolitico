/// Resposta de `candidato_campanha_public` (Supabase RPC).
class CandidatoCampanhaPublic {
  const CandidatoCampanhaPublic({
    required this.id,
    this.fullName,
    this.avatarUrl,
    this.partidoBandeiraUrl,
  });

  final String id;
  final String? fullName;
  final String? avatarUrl;
  final String? partidoBandeiraUrl;

  /// Mesma prioridade que [Profile.sidebarBrandImageUrl]: avatar, senão bandeira.
  String? get sidebarBrandImageUrl {
    final a = avatarUrl?.trim();
    if (a != null && a.isNotEmpty) return a;
    final b = partidoBandeiraUrl?.trim();
    if (b != null && b.isNotEmpty) return b;
    return null;
  }

  static CandidatoCampanhaPublic? tryParse(dynamic raw) {
    if (raw == null) return null;
    Map<String, dynamic>? m;
    if (raw is Map<String, dynamic>) {
      m = raw;
    } else if (raw is Map) {
      m = Map<String, dynamic>.from(raw);
    }
    if (m == null || m.isEmpty) return null;
    final id = m['id']?.toString();
    if (id == null || id.isEmpty) return null;
    return CandidatoCampanhaPublic(
      id: id,
      fullName: m['full_name'] as String?,
      avatarUrl: m['avatar_url'] as String?,
      partidoBandeiraUrl: m['partido_bandeira_url'] as String?,
    );
  }
}
