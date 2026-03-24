class Assessor {
  final String id;
  final String profileId;
  final String nome;
  final String? telefone;
  final String? email;
  final String? municipioId;
  final bool ativo;
  final String? cep;
  final String? logradouro;
  final String? numero;
  final String? complemento;

  const Assessor({
    required this.id,
    required this.profileId,
    required this.nome,
    this.telefone,
    this.email,
    this.municipioId,
    this.ativo = true,
    this.cep,
    this.logradouro,
    this.numero,
    this.complemento,
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
      cep: json['cep'] as String?,
      logradouro: json['logradouro'] as String?,
      numero: json['numero'] as String?,
      complemento: json['complemento'] as String?,
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
        'cep': cep,
        'logradouro': logradouro,
        'numero': numero,
        'complemento': complemento,
      };

  String get initial => nome.isNotEmpty ? nome[0].toUpperCase() : '?';
}
