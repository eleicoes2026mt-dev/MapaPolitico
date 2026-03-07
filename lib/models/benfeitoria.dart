class Benfeitoria {
  final String id;
  final String apoiadorId;
  final String? municipioId;
  final String titulo;
  final String? descricao;
  final double valor;
  final DateTime? dataRealizacao;
  final String tipo; // Reforma, Obra, Doação, Evento, Outro
  final String status; // em_andamento, concluida, planejada
  final String? fotoUrl;

  const Benfeitoria({
    required this.id,
    required this.apoiadorId,
    this.municipioId,
    required this.titulo,
    this.descricao,
    this.valor = 0,
    this.dataRealizacao,
    this.tipo = 'Outro',
    this.status = 'em_andamento',
    this.fotoUrl,
  });

  factory Benfeitoria.fromJson(Map<String, dynamic> json) {
    final d = json['data_realizacao'];
    return Benfeitoria(
      id: json['id'] as String,
      apoiadorId: json['apoiador_id'] as String,
      municipioId: json['municipio_id'] as String?,
      titulo: json['titulo'] as String,
      descricao: json['descricao'] as String?,
      valor: (json['valor'] as num?)?.toDouble() ?? 0,
      dataRealizacao: d != null ? DateTime.tryParse(d.toString()) : null,
      tipo: json['tipo'] as String? ?? 'Outro',
      status: json['status'] as String? ?? 'em_andamento',
      fotoUrl: json['foto_url'] as String?,
    );
  }

  bool get isConcluida => status == 'concluida';
  bool get isEmAndamento => status == 'em_andamento';
}
