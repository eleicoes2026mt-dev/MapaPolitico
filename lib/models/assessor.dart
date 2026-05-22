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
  /// 1 = mesma gestão que o candidato; 2 = assessor padrão.
  final int grauAcesso;
  /// URL ou @ do Instagram (opcional).
  final String? linkInstagram;
  /// Papel em `profiles` quando a listagem traz embed (ex.: `profiles(role)`).
  final String? profilesRole;

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
    this.grauAcesso = 2,
    this.linkInstagram,
    this.profilesRole,
  });

  factory Assessor.fromJson(Map<String, dynamic> json) {
    String? nestedRole;
    final pr = json['profiles'];
    if (pr is Map<String, dynamic>) {
      nestedRole = pr['role'] as String?;
    } else if (pr is List && pr.isNotEmpty && pr.first is Map) {
      nestedRole = (pr.first as Map)['role'] as String?;
    }
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
      grauAcesso: (json['grau_acesso'] as num?)?.toInt() ?? 2,
      linkInstagram: json['link_instagram'] as String?,
      profilesRole: nestedRole,
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
        'grau_acesso': grauAcesso,
        'link_instagram': linkInstagram,
      };

  String get initial => nome.isNotEmpty ? nome[0].toUpperCase() : '?';
}
