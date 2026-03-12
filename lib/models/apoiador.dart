class Apoiador {
  final String id;
  final String? profileId;
  final String assessorId;
  final String nome;
  final String tipo; // PF | PJ
  final String? perfil;
  final String? telefone;
  final String? email;
  final int estimativaVotos;
  final List<String> cidadesAtuacaoIds;
  final bool ativo;
  final String? municipioId;
  final String? cidadeNome;
  final DateTime? dataNascimento;
  final bool votosSozinho;
  final int qtdVotosFamilia;
  final String? cnpj;
  final String? razaoSocial;
  final String? nomeFantasia;
  final String? situacaoCnpj;
  final String? endereco;
  final String? contatoResponsavel;
  final String? emailResponsavel;
  final int votosPf;
  final int votosFamilia;
  final int votosFuncionarios;
  final int? votosPrometidosUltimaEleicao;

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
    this.municipioId,
    this.cidadeNome,
    this.dataNascimento,
    this.votosSozinho = true,
    this.qtdVotosFamilia = 0,
    this.cnpj,
    this.razaoSocial,
    this.nomeFantasia,
    this.situacaoCnpj,
    this.endereco,
    this.contatoResponsavel,
    this.emailResponsavel,
    this.votosPf = 0,
    this.votosFamilia = 0,
    this.votosFuncionarios = 0,
    this.votosPrometidosUltimaEleicao,
  });

  factory Apoiador.fromJson(Map<String, dynamic> json) {
    final list = json['cidades_atuacao'];
    final dn = json['data_nascimento'];
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
      municipioId: json['municipio_id'] as String?,
      cidadeNome: json['cidade_nome'] as String?,
      dataNascimento: dn != null ? DateTime.tryParse(dn.toString()) : null,
      votosSozinho: json['votos_sozinho'] as bool? ?? true,
      qtdVotosFamilia: (json['qtd_votos_familia'] as num?)?.toInt() ?? 0,
      cnpj: json['cnpj'] as String?,
      razaoSocial: json['razao_social'] as String?,
      nomeFantasia: json['nome_fantasia'] as String?,
      situacaoCnpj: json['situacao_cnpj'] as String?,
      endereco: json['endereco'] as String?,
      contatoResponsavel: json['contato_responsavel'] as String?,
      emailResponsavel: json['email_responsavel'] as String?,
      votosPf: (json['votos_pf'] as num?)?.toInt() ?? 0,
      votosFamilia: (json['votos_familia'] as num?)?.toInt() ?? 0,
      votosFuncionarios: (json['votos_funcionarios'] as num?)?.toInt() ?? 0,
      votosPrometidosUltimaEleicao: (json['votos_prometidos_ultima_eleicao'] as num?)?.toInt(),
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
        'municipio_id': municipioId,
        'cidade_nome': cidadeNome,
        'data_nascimento': dataNascimento?.toIso8601String().split('T').first,
        'votos_sozinho': votosSozinho,
        'qtd_votos_familia': qtdVotosFamilia,
        'cnpj': cnpj,
        'razao_social': razaoSocial,
        'nome_fantasia': nomeFantasia,
        'situacao_cnpj': situacaoCnpj,
        'endereco': endereco,
        'contato_responsavel': contatoResponsavel,
        'email_responsavel': emailResponsavel,
        'votos_pf': votosPf,
        'votos_familia': votosFamilia,
        'votos_funcionarios': votosFuncionarios,
        'votos_prometidos_ultima_eleicao': votosPrometidosUltimaEleicao,
      };

  /// Nome da cidade para exibição no mapa (cidade_nome ou derivado).
  String? get cidadeParaMapa => cidadeNome;

  String get initial => nome.isNotEmpty ? nome[0].toUpperCase() : '?';
  bool get isPJ => tipo == 'PJ';
}
