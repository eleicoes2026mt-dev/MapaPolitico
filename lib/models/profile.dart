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
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      fullName: json['full_name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      role: json['role'] as String,
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
