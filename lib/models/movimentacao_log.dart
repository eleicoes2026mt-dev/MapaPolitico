/// Linha de `campanha_movimentacao_logs` (ping de atividade no Supabase).
class MovimentacaoLog {
  const MovimentacaoLog({
    required this.id,
    required this.profileId,
    required this.origem,
    required this.createdAt,
  });

  final String id;
  final String profileId;
  /// `manual` | `auto_app`
  final String origem;
  final DateTime createdAt;

  factory MovimentacaoLog.fromJson(Map<String, dynamic> json) {
    return MovimentacaoLog(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      origem: json['origem'] as String,
      createdAt: DateTime.parse(json['created_at'].toString()),
    );
  }

  String get origemLabelPt {
    switch (origem) {
      case 'manual':
        return 'Manual';
      case 'auto_app':
        return 'Automático (app)';
      default:
        return origem;
    }
  }
}
