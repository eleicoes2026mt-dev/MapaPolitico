class Municipio {
  final String id;
  final String nome;
  final String nomeNormalizado;
  final String? codigoIbge;
  final String poloId;
  final String? subRegiaoCuiaba;

  const Municipio({
    required this.id,
    required this.nome,
    required this.nomeNormalizado,
    this.codigoIbge,
    required this.poloId,
    this.subRegiaoCuiaba,
  });

  factory Municipio.fromJson(Map<String, dynamic> json) {
    return Municipio(
      id: json['id'] as String,
      nome: json['nome'] as String,
      nomeNormalizado: json['nome_normalizado'] as String,
      codigoIbge: json['codigo_ibge'] as String?,
      poloId: json['polo_id'] as String,
      subRegiaoCuiaba: json['sub_regiao_cuiaba'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'nome_normalizado': nomeNormalizado,
        'codigo_ibge': codigoIbge,
        'polo_id': poloId,
        'sub_regiao_cuiaba': subRegiaoCuiaba,
      };
}
