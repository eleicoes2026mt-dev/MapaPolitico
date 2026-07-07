class Mensagem {
  final String id;
  final String titulo;
  final String? corpo;
  /// Link opcional (rede social, site), repassado no push e na lista.
  final String? linkUrl;
  /// Imagem opcional (URL Storage), enviada com o corpo/lista e referência no push.
  final String? imagemUrl;
  /// PDF opcional (URL Storage mensagens/<uid>/<id>.pdf).
  final String? pdfUrl;
  /// global | polo | cidade | performance | reuniao | privada_assessores | privada_apoiadores | apoiador_classificacao
  final String escopo;
  final String? poloId;
  /// Com escopo `apoiador_classificacao`: mesmo texto que `apoiadores.perfil` no cadastro.
  final String? classificacaoApoiador;
  final List<String> municipiosIds;
  final String? statusPerformanceFiltro;
  final String? reuniaoId;
  final DateTime? enviadaEm;
  final String? criadoPor;

  const Mensagem({
    required this.id,
    required this.titulo,
    this.corpo,
    this.linkUrl,
    this.imagemUrl,
    this.pdfUrl,
    this.escopo = 'global',
    this.poloId,
    this.classificacaoApoiador,
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
      linkUrl: json['link_url'] as String?,
      imagemUrl: json['imagem_url'] as String?,
      pdfUrl: json['pdf_url'] as String?,
      escopo: json['escopo'] as String? ?? 'global',
      poloId: json['polo_id'] as String?,
      classificacaoApoiador: json['classificacao_apoiador'] as String?,
      municipiosIds: list is List ? list.map((e) => e.toString()).toList() : [],
      statusPerformanceFiltro: json['status_performance_filtro'] as String?,
      reuniaoId: json['reuniao_id'] as String?,
      enviadaEm: json['enviada_em'] != null ? DateTime.tryParse(json['enviada_em'].toString()) : null,
      criadoPor: json['criado_por'] as String?,
    );
  }

  /// Corpo da notificação push / in-app: texto + link, se houver.
  static String textoParaNotificacao({
    String? corpo,
    String? linkUrl,
    String? imagemUrl,
  }) {
    final c = corpo?.trim();
    final l = linkUrl?.trim();
    final i = imagemUrl?.trim();
    final parts = <String>[];
    if (c != null && c.isNotEmpty) parts.add(c);
    if (l != null && l.isNotEmpty) parts.add('🔗 $l');
    if (i != null && i.isNotEmpty) parts.add('📷 Mensagem com imagem');
    if (parts.isEmpty) return 'Nova mensagem da campanha.';
    return parts.join('\n\n');
  }

  /// Normaliza URL para gravação (aceita `instagram.com/...` sem esquema).
  static String? normalizarLinkOpcional(String? raw) {
    final s = raw?.trim();
    if (s == null || s.isEmpty) return null;
    final lower = s.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) return s;
    if (lower.startsWith('www.')) return 'https://$s';
    return 'https://$s';
  }

  /// Validação simples antes de salvar (opcional: [raw] vazio = válido).
  static String? erroValidacaoLink(String? raw) {
    final s = raw?.trim();
    if (s == null || s.isEmpty) return null;
    final n = normalizarLinkOpcional(s)!;
    final u = Uri.tryParse(n);
    if (u == null || !u.hasScheme || u.host.isEmpty) {
      return 'Informe um link válido (ex.: instagram.com/seuperfil ou https://…)';
    }
    if (u.scheme != 'http' && u.scheme != 'https') {
      return 'Use apenas links http ou https.';
    }
    return null;
  }
}
