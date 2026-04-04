class Partido {
  const Partido({
    required this.id,
    required this.sigla,
    required this.nome,
    this.bandeiraUrl,
  });

  final String id;
  final String sigla;
  final String nome;
  final String? bandeiraUrl;

  factory Partido.fromJson(Map<String, dynamic> json) {
    return Partido(
      id: json['id'] as String,
      sigla: (json['sigla'] as String?)?.trim() ?? '',
      nome: (json['nome'] as String?)?.trim() ?? '',
      bandeiraUrl: json['bandeira_url'] as String?,
    );
  }
}
