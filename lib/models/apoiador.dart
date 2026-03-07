class Apoiador {
  final String id;
  final String? profileId;
  final String assessorId;
  final String nome;
  final String tipo; // PF | PJ
  final String? perfil; // Prefeitural, Vereador, Líder Religional, Empresarial
  final String? telefone;
  final String? email;
  final int estimativaVotos;
  final List<String> cidadesAtuacaoIds;
  final bool ativo;

  const Apoiador({
    required this.id,
    this.profileId,
    required this.assessorId,
    required this.nome,
    this.tipo = 'PF',
    this.perfil,
    this.telefone,
    this.email,
    this.estimativaVotos = 0,
    this.cidadesAtuacaoIds = const [],
    this.ativo = true,
  });

  factory Apoiador.fromJson(Map<String, dynamic> json) {
    final list = json['cidades_atuacao'];
    return Apoiador(
      id: json['id'] as String,
      profileId: json['profile_id'] as String?,
      assessorId: json['assessor_id'] as String,
      nome: json['nome'] as String,
      tipo: json['tipo'] as String? ?? 'PF',
      perfil: json['perfil'] as String?,
      telefone: json['telefone'] as String?,
      email: json['email'] as String?,
      estimativaVotos: (json['estimativa_votos'] as num?)?.toInt() ?? 0,
      cidadesAtuacaoIds: list is List ? list.map((e) => e.toString()).toList() : [],
      ativo: json['ativo'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'profile_id': profileId,
        'assessor_id': assessorId,
        'nome': nome,
        'tipo': tipo,
        'perfil': perfil,
        'telefone': telefone,
        'email': email,
        'estimativa_votos': estimativaVotos,
        'cidades_atuacao': cidadesAtuacaoIds,
        'ativo': ativo,
      };

  String get initial => nome.isNotEmpty ? nome[0].toUpperCase() : '?';
  bool get isPJ => tipo == 'PJ';
}
