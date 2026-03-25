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
  /// Nome de cidade em texto livre — salvo mesmo quando municipio_id não pôde ser resolvido.
  final String? cidadeNome;
  final String abrangencia; // Individual | Familiar
  final int qtdVotosFamilia;
  final String? cep;
  final String? logradouro;
  final String? numero;
  final String? complemento;

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
    this.cidadeNome,
    this.abrangencia = 'Individual',
    this.qtdVotosFamilia = 1,
    this.cep,
    this.logradouro,
    this.numero,
    this.complemento,
  });

  /// Nome de exibição da cidade: join > texto livre > '—'.
  String get cidadeDisplay => municipioNome ?? cidadeNome ?? '';

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
      cidadeNome: json['cidade_nome'] as String?,
      abrangencia: json['abrangencia'] as String? ?? 'Individual',
      qtdVotosFamilia: (json['qtd_votos_familia'] as num?)?.toInt() ?? 1,
      cep: json['cep'] as String?,
      logradouro: json['logradouro'] as String?,
      numero: json['numero'] as String?,
      complemento: json['complemento'] as String?,
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
        'cidade_nome': cidadeNome,
        'abrangencia': abrangencia,
        'qtd_votos_familia': qtdVotosFamilia,
        'cep': cep,
        'logradouro': logradouro,
        'numero': numero,
        'complemento': complemento,
      };
}
