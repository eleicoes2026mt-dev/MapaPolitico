/// Linha de auditoria da campanha (Supabase `campanha_audit_log`).
class CampanhaAuditLog {
  const CampanhaAuditLog({
    required this.id,
    required this.candidatoProfileId,
    this.actorProfileId,
    required this.tableName,
    required this.recordId,
    required this.action,
    this.payloadBefore,
    this.payloadAfter,
    required this.createdAt,
  });

  final String id;
  final String candidatoProfileId;
  final String? actorProfileId;
  final String tableName;
  final String recordId;
  final String action;
  final Map<String, dynamic>? payloadBefore;
  final Map<String, dynamic>? payloadAfter;
  final DateTime createdAt;

  factory CampanhaAuditLog.fromJson(Map<String, dynamic> json) {
    return CampanhaAuditLog(
      id: json['id'] as String,
      candidatoProfileId: json['candidato_profile_id'] as String,
      actorProfileId: json['actor_profile_id'] as String?,
      tableName: json['table_name'] as String,
      recordId: json['record_id'] as String,
      action: json['action'] as String,
      payloadBefore: json['payload_before'] is Map ? Map<String, dynamic>.from(json['payload_before'] as Map) : null,
      payloadAfter: json['payload_after'] is Map ? Map<String, dynamic>.from(json['payload_after'] as Map) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get tableLabelPt {
    switch (tableName) {
      case 'assessores':
        return 'Assessores';
      case 'apoiadores':
        return 'Apoiadores';
      case 'votantes':
        return 'Votantes';
      case 'benfeitorias':
        return 'Benfeitorias';
      default:
        return tableName;
    }
  }

  String get actionLabelPt {
    switch (action) {
      case 'insert':
        return 'Inclusão';
      case 'update':
        return 'Edição';
      case 'delete':
        return 'Exclusão';
      case 'restore':
        return 'Restauração';
      default:
        return action;
    }
  }
}
