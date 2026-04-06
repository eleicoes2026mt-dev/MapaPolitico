class ApoiadorOrigemLugar {
  const ApoiadorOrigemLugar({
    required this.id,
    required this.assessorId,
    required this.nome,
  });

  final String id;
  final String assessorId;
  final String nome;

  factory ApoiadorOrigemLugar.fromJson(Map<String, dynamic> json) {
    return ApoiadorOrigemLugar(
      id: json['id'] as String,
      assessorId: json['assessor_id'] as String,
      nome: (json['nome'] as String).trim(),
    );
  }
}
