class Mensagem {
  final String id;
  final String titulo;
  final String? corpo;
  final String escopo; // global, polo, cidade, performance, reuniao
  final String? poloId;
  final List<String> municipiosIds;
  final String? statusPerformanceFiltro;
  final String? reuniaoId;
  final DateTime? enviadaEm;
  final String? criadoPor;

  const Mensagem({
    required this.id,
    required this.titulo,
    this.corpo,
    this.escopo = 'global',
    this.poloId,
    this.municipiosIds = const [],
    this.statusPerformanceFiltro,
    this.reuniaoId,
    this.enviadaEm,
    this.criadoPor,
  });

  factory Mensagem.fromJson(Map<String, dynamic> json) {
    final list = json['municipios_ids'];
    return Mensagem(
      id: json['id'] as String,
      titulo: json['titulo'] as String,
      corpo: json['corpo'] as String?,
      escopo: json['escopo'] as String? ?? 'global',
      poloId: json['polo_id'] as String?,
      municipiosIds: list is List ? list.map((e) => e.toString()).toList() : [],
      statusPerformanceFiltro: json['status_performance_filtro'] as String?,
      reuniaoId: json['reuniao_id'] as String?,
      enviadaEm: json['enviada_em'] != null ? DateTime.tryParse(json['enviada_em'].toString()) : null,
      criadoPor: json['criado_por'] as String?,
    );
  }
}
