class Votante {
  final String id;
  final String? profileId;
  final String? assessorId;
  final String? apoiadorId;
  final String nome;
  final String? telefone;
  final String? email;
  final String? municipioId;
  /// Preenchido quando a lista vem com join `municipios(nome)`.
  final String? municipioNome;
  final String abrangencia; // Individual | Familiar
  final int qtdVotosFamilia;

  const Votante({
    required this.id,
    this.profileId,
    this.assessorId,
    this.apoiadorId,
    required this.nome,
    this.telefone,
    this.email,
    this.municipioId,
    this.municipioNome,
    this.abrangencia = 'Individual',
    this.qtdVotosFamilia = 1,
  });

  factory Votante.fromJson(Map<String, dynamic> json) {
    final mun = json['municipios'];
    String? munNome;
    if (mun is Map && mun['nome'] != null) {
      munNome = mun['nome'].toString();
    }
    return Votante(
      id: json['id'] as String,
      profileId: json['profile_id'] as String?,
      assessorId: json['assessor_id'] as String?,
      apoiadorId: json['apoiador_id'] as String?,
      nome: json['nome'] as String,
      telefone: json['telefone'] as String?,
      email: json['email'] as String?,
      municipioId: json['municipio_id'] as String?,
      municipioNome: munNome,
      abrangencia: json['abrangencia'] as String? ?? 'Individual',
      qtdVotosFamilia: (json['qtd_votos_familia'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'profile_id': profileId,
        'assessor_id': assessorId,
        'apoiador_id': apoiadorId,
        'nome': nome,
        'telefone': telefone,
        'email': email,
        'municipio_id': municipioId,
        'abrangencia': abrangencia,
        'qtd_votos_familia': qtdVotosFamilia,
      };
}
