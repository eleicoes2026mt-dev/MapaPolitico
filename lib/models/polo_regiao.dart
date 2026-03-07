class PoloRegiao {
  final String id;
  final String nome;
  final String? subRegiao;
  final String? descricao;
  final String corHex;
  final int ordem;

  const PoloRegiao({
    required this.id,
    required this.nome,
    this.subRegiao,
    this.descricao,
    this.corHex = '#1976D2',
    this.ordem = 0,
  });

  factory PoloRegiao.fromJson(Map<String, dynamic> json) {
    return PoloRegiao(
      id: json['id'] as String,
      nome: json['nome'] as String,
      subRegiao: json['sub_regiao'] as String?,
      descricao: json['descricao'] as String?,
      corHex: (json['cor_hex'] as String?) ?? '#1976D2',
      ordem: (json['ordem'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'sub_regiao': subRegiao,
        'descricao': descricao,
        'cor_hex': corHex,
        'ordem': ordem,
      };
}
