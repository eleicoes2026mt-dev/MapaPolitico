class MetaRegional {
  final String id;
  final String poloId;
  final int metaVotos;
  final double percentualDistribuicao;
  final String? responsavelId;

  const MetaRegional({
    required this.id,
    required this.poloId,
    required this.metaVotos,
    this.percentualDistribuicao = 0,
    this.responsavelId,
  });

  factory MetaRegional.fromJson(Map<String, dynamic> json) {
    return MetaRegional(
      id: json['id'] as String,
      poloId: json['polo_id'] as String,
      metaVotos: (json['meta_votos'] as num?)?.toInt() ?? 0,
      percentualDistribuicao: (json['percentual_distribuicao'] as num?)?.toDouble() ?? 0,
      responsavelId: json['responsavel_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'polo_id': poloId,
        'meta_votos': metaVotos,
        'percentual_distribuicao': percentualDistribuicao,
        'responsavel_id': responsavelId,
      };
}
