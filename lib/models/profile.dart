class Profile {
  final String id;
  final String? fullName;
  final String? email;
  final String? phone;
  final String role;
  final String? invitedBy;
  final String? regionalPoloId;
  final String? avatarUrl;
  final bool ativo;
  final String? cargo;
  final String? partido;
  /// FK opcional para [partidos]; a bandeira vem do join `partidos`.
  final String? partidoId;
  final String? partidoBandeiraUrl;
  final String? partidoSiglaJoin;
  final String? numeroCandidato;
  final DateTime? dataNascimento;
  final int? sqCandidatoTse2022;
  final DateTime? lastAccessAssessoresAt;
  final DateTime? lastAccessApoiadoresAt;

  const Profile({
    required this.id,
    this.fullName,
    this.email,
    this.phone,
    required this.role,
    this.invitedBy,
    this.regionalPoloId,
    this.avatarUrl,
    this.ativo = true,
    this.cargo,
    this.partido,
    this.partidoId,
    this.partidoBandeiraUrl,
    this.partidoSiglaJoin,
    this.numeroCandidato,
    this.dataNascimento,
    this.sqCandidatoTse2022,
    this.lastAccessAssessoresAt,
    this.lastAccessApoiadoresAt,
  });

  /// Normaliza o papel vindo do PostgREST (`app_role` → string).
  static String roleFromJson(dynamic raw) {
    if (raw == null) return 'votante';
    final s = raw.toString().trim().toLowerCase();
    if (s.isEmpty) return 'votante';
    // Alguns painéis/editores mostram rótulo em inglês; o enum real é PT.
    if (s == 'candidate') return 'candidato';
    return s;
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    String? bandeira;
    String? siglaJoin;
    dynamic pj = json['partidos'];
    if (pj is List && pj.isNotEmpty) {
      pj = pj.first;
    }
    if (pj is Map) {
      bandeira = pj['bandeira_url'] as String?;
      siglaJoin = pj['sigla'] as String?;
    }

    return Profile(
      id: json['id'] as String,
      fullName: json['full_name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      role: roleFromJson(json['role']),
      invitedBy: json['invited_by'] as String?,
      regionalPoloId: json['regional_polo_id'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      ativo: json['ativo'] as bool? ?? true,
      cargo: json['cargo'] as String?,
      partido: json['partido'] as String?,
      partidoId: json['partido_id'] as String?,
      partidoBandeiraUrl: bandeira,
      partidoSiglaJoin: siglaJoin,
      numeroCandidato: json['numero_candidato'] as String?,
      dataNascimento: json['data_nascimento'] != null
          ? DateTime.tryParse(json['data_nascimento'].toString())
          : null,
      sqCandidatoTse2022: (json['sq_candidato_tse_2022'] as num?)?.toInt(),
      lastAccessAssessoresAt: json['last_access_assessores_at'] != null
          ? DateTime.tryParse(json['last_access_assessores_at'].toString())
          : null,
      lastAccessApoiadoresAt: json['last_access_apoiadores_at'] != null
          ? DateTime.tryParse(json['last_access_apoiadores_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'full_name': fullName,
        'phone': phone,
        'cargo': cargo,
        'partido': partido,
        if (partidoId != null) 'partido_id': partidoId,
        'numero_candidato': numeroCandidato,
      };

  /// Imagem no topo do menu: foto de perfil primeiro; senão bandeira do partido.
  String? get sidebarBrandImageUrl {
    final a = avatarUrl?.trim();
    if (a != null && a.isNotEmpty) {
      return a;
    }
    final b = partidoBandeiraUrl?.trim();
    if (b != null && b.isNotEmpty) {
      return b;
    }
    return null;
  }

  bool get isCandidato => role == 'candidato';
  bool get isAssessor => role == 'assessor';
}
