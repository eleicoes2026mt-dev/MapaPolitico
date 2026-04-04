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
        'numero_candidato': numeroCandidato,
      };

  bool get isCandidato => role == 'candidato';
  bool get isAssessor => role == 'assessor';
}
