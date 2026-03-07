class Assessor {
  final String id;
  final String profileId;
  final String nome;
  final String? telefone;
  final String? email;
  final String? municipioId;
  final bool ativo;

  const Assessor({
    required this.id,
    required this.profileId,
    required this.nome,
    this.telefone,
    this.email,
    this.municipioId,
    this.ativo = true,
  });

  factory Assessor.fromJson(Map<String, dynamic> json) {
    return Assessor(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      nome: json['nome'] as String,
      telefone: json['telefone'] as String?,
      email: json['email'] as String?,
      municipioId: json['municipio_id'] as String?,
      ativo: json['ativo'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'profile_id': profileId,
        'nome': nome,
        'telefone': telefone,
        'email': email,
        'municipio_id': municipioId,
        'ativo': ativo,
      };

  String get initial => nome.isNotEmpty ? nome[0].toUpperCase() : '?';
}
