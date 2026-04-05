import 'package:intl/intl.dart';

class Visita {
  const Visita({
    required this.id,
    required this.titulo,
    required this.dataReuniao,
    this.hora,
    this.localTexto,
    this.localLat,
    this.localLng,
    this.descricao,
    this.municipioId,
    this.municipioNome,
    this.criadoPor,
    this.notificadosEm,
    this.visivelApoiadores = true,
    this.notificacaoProfileIds = const [],
  });

  final String id;
  final String titulo;
  final DateTime dataReuniao;
  final String? hora; // "HH:MM"
  final String? localTexto;
  final double? localLat;
  final double? localLng;
  final String? descricao;
  final String? municipioId;
  final String? municipioNome;
  final String? criadoPor;
  final DateTime? notificadosEm;
  final bool visivelApoiadores;
  /// Quando [visivelApoiadores] é false, só estes perfis recebem push e veem a visita (apoiador).
  final List<String> notificacaoProfileIds;

  bool get agendaPrivada =>
      !visivelApoiadores && notificacaoProfileIds.isNotEmpty;

  bool get isFutura => dataReuniao.isAfter(DateTime.now().subtract(const Duration(days: 1)));
  bool get isHoje {
    final hoje = DateTime.now();
    return dataReuniao.year == hoje.year &&
        dataReuniao.month == hoje.month &&
        dataReuniao.day == hoje.day;
  }

  String get dataFormatada => DateFormat('dd/MM/yyyy').format(dataReuniao);
  String get horaFormatada => hora ?? '';

  /// Exibe hora em HH:mm (remove segundos vindos do banco, ex.: 09:00:00).
  String get horaExibicao {
    if (hora == null || hora!.trim().isEmpty) return '';
    final p = hora!.trim().split(':');
    if (p.length >= 2) {
      final h = int.tryParse(p[0].trim());
      final m = int.tryParse(p[1].trim());
      if (h != null && m != null) {
        return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
      }
    }
    return hora!.trim();
  }

  String get dataHoraFormatada =>
      horaExibicao.isNotEmpty ? '$dataFormatada às $horaExibicao' : dataFormatada;

  factory Visita.fromJson(Map<String, dynamic> json) {
    final mun = json['municipios'];
    final munNome = mun is Map ? mun['nome']?.toString() : null;
    return Visita(
      id: json['id'] as String,
      titulo: json['titulo'] as String,
      dataReuniao: DateTime.parse(json['data_reuniao'] as String),
      hora: json['hora'] as String?,
      localTexto: json['local_texto'] as String?,
      localLat: (json['local_lat'] as num?)?.toDouble(),
      localLng: (json['local_lng'] as num?)?.toDouble(),
      descricao: json['descricao'] as String?,
      municipioId: json['municipio_id'] as String?,
      municipioNome: munNome,
      criadoPor: json['criado_por'] as String?,
      notificadosEm: json['notificados_em'] != null
          ? DateTime.tryParse(json['notificados_em'].toString())
          : null,
      visivelApoiadores: json['visivel_apoiadores'] as bool? ?? true,
      notificacaoProfileIds: _parseUuidList(json['notificacao_profile_ids']),
    );
  }

  static List<String> _parseUuidList(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    }
    return const [];
  }

  Map<String, dynamic> toInsertJson() => {
        'titulo': titulo,
        'data_reuniao': dataReuniao.toIso8601String().split('T').first,
        if (hora != null && hora!.isNotEmpty) 'hora': hora,
        if (localTexto != null && localTexto!.isNotEmpty) 'local_texto': localTexto,
        if (localLat != null) 'local_lat': localLat,
        if (localLng != null) 'local_lng': localLng,
        if (descricao != null && descricao!.isNotEmpty) 'descricao': descricao,
        if (municipioId != null) 'municipio_id': municipioId,
        'visivel_apoiadores': visivelApoiadores,
        'notificacao_profile_ids': notificacaoProfileIds,
      };
}

class Aniversariante {
  const Aniversariante({
    required this.nome,
    required this.dataNascimento,
    this.telefone,
    this.email,
    required this.tipo,
    required this.refId,
    this.municipioNome,
  });

  final String nome;
  final DateTime dataNascimento;
  final String? telefone;
  final String? email;
  final String tipo; // 'apoiador' | 'assessor' | 'votante'
  final String refId;
  final String? municipioNome;

  bool get isHoje {
    final hoje = DateTime.now();
    return dataNascimento.month == hoje.month && dataNascimento.day == hoje.day;
  }

  int get idadeAnos {
    final hoje = DateTime.now();
    int anos = hoje.year - dataNascimento.year;
    if (hoje.month < dataNascimento.month ||
        (hoje.month == dataNascimento.month && hoje.day < dataNascimento.day)) {
      anos--;
    }
    return anos;
  }

  int get diasParaAniversario {
    final hoje = DateTime.now();
    var proximo = DateTime(hoje.year, dataNascimento.month, dataNascimento.day);
    if (proximo.isBefore(hoje)) proximo = DateTime(hoje.year + 1, dataNascimento.month, dataNascimento.day);
    return proximo.difference(DateTime(hoje.year, hoje.month, hoje.day)).inDays;
  }

  /// Dígitos com DDI 55 (ex.: 5565999999999), para `wa.me`, `jid` e partilha direta no WhatsApp.
  String? get telefoneWhatsappDigits {
    if (telefone == null || telefone!.isEmpty) return null;
    final digits = telefone!.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return null;
    return digits.startsWith('55') ? digits : '55$digits';
  }

  String get whatsappUrl {
    final ddi = telefoneWhatsappDigits;
    if (ddi == null) return '';
    final msg = Uri.encodeComponent(
      'Olá $nome! 🎂 Feliz aniversário! Estamos juntos nessa caminhada. Abraços!',
    );
    return 'https://wa.me/$ddi?text=$msg';
  }
}
