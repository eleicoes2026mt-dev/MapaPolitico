import 'package:intl/intl.dart';

/// Valores de [Visita.agendaStatus] alinhados à coluna `reunioes.agenda_status`.
abstract class AgendaVisitaStatus {
  static const agendado = 'agendado';
  static const realizada = 'realizada';
}

class Visita {
  const Visita({
    required this.id,
    required this.titulo,
    required this.dataReuniao,
    this.hora,
    this.dataReuniaoFim,
    this.horaFim,
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
    this.agendaStatus = AgendaVisitaStatus.agendado,
  });

  final String id;
  final String titulo;
  final DateTime dataReuniao;
  final String? hora; // "HH:MM"
  /// Último dia do período; null = evento só em [dataReuniao].
  final DateTime? dataReuniaoFim;
  final String? horaFim;
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

  /// `agendado` ou `realizada` (vide [AgendaVisitaStatus]).
  final String agendaStatus;

  bool get isAgendaRealizada => agendaStatus == AgendaVisitaStatus.realizada;

  String get agendaStatusLabelPt =>
      isAgendaRealizada ? 'Agenda realizada' : 'Agendado';

  bool get agendaPrivada =>
      !visivelApoiadores && notificacaoProfileIds.isNotEmpty;

  DateTime get _dataInicioDia =>
      DateTime(dataReuniao.year, dataReuniao.month, dataReuniao.day);

  DateTime get _dataFimDia {
    final f = dataReuniaoFim ?? dataReuniao;
    return DateTime(f.year, f.month, f.day);
  }

  /// O dia [d] (qualquer hora) está entre o início e o fim do período (inclusive).
  bool cobreDia(DateTime d) {
    final dia = DateTime(d.year, d.month, d.day);
    return !dia.isBefore(_dataInicioDia) && !dia.isAfter(_dataFimDia);
  }

  bool get isFutura {
    final cutoff = DateTime.now().subtract(const Duration(days: 1));
    final limite = DateTime(cutoff.year, cutoff.month, cutoff.day);
    return !_dataFimDia.isBefore(limite);
  }

  bool get isHoje {
    final hoje = DateTime.now();
    final dia = DateTime(hoje.year, hoje.month, hoje.day);
    return !dia.isBefore(_dataInicioDia) && !dia.isAfter(_dataFimDia);
  }

  String get dataFormatada => DateFormat('dd/MM/yyyy').format(dataReuniao);
  String get horaFormatada => hora ?? '';

  String get dataFimFormatada => dataReuniaoFim != null
      ? DateFormat('dd/MM/yyyy').format(dataReuniaoFim!)
      : '';

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

  /// Exibe hora de término em HH:mm.
  String get horaFimExibicao {
    if (horaFim == null || horaFim!.trim().isEmpty) return '';
    final p = horaFim!.trim().split(':');
    if (p.length >= 2) {
      final h = int.tryParse(p[0].trim());
      final m = int.tryParse(p[1].trim());
      if (h != null && m != null) {
        return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
      }
    }
    return horaFim!.trim();
  }

  String get _inicioTexto =>
      horaExibicao.isNotEmpty ? '$dataFormatada às $horaExibicao' : dataFormatada;

  String get _fimTexto {
    if (dataReuniaoFim == null) return '';
    if (horaFimExibicao.isNotEmpty) {
      return '${DateFormat('dd/MM/yyyy').format(dataReuniaoFim!)} às $horaFimExibicao';
    }
    return DateFormat('dd/MM/yyyy').format(dataReuniaoFim!);
  }

  /// Período completo (início e, se houver, fim).
  String get dataHoraFormatada =>
      dataReuniaoFim != null ? '$_inicioTexto a $_fimTexto' : _inicioTexto;

  /// Linha compacta para o card: horas no mesmo dia ou texto completo em períodos longos.
  String get horarioOuPeriodoCard {
    if (dataReuniaoFim == null) return horaExibicao;
    final mesmoDia = _dataInicioDia == _dataFimDia;
    if (mesmoDia && horaExibicao.isNotEmpty && horaFimExibicao.isNotEmpty) {
      return '$horaExibicao – $horaFimExibicao';
    }
    return dataHoraFormatada;
  }

  factory Visita.fromJson(Map<String, dynamic> json) {
    final mun = json['municipios'];
    final munNome = mun is Map ? mun['nome']?.toString() : null;
    return Visita(
      id: json['id'] as String,
      titulo: json['titulo'] as String,
      dataReuniao: DateTime.parse(json['data_reuniao'] as String),
      hora: json['hora'] as String?,
      dataReuniaoFim: json['data_reuniao_fim'] != null
          ? DateTime.tryParse(json['data_reuniao_fim'].toString())
          : null,
      horaFim: json['hora_fim'] as String?,
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
      agendaStatus: _parseAgendaStatus(json['agenda_status']),
    );
  }

  static String _parseAgendaStatus(dynamic raw) {
    final s = raw?.toString().trim().toLowerCase();
    if (s == AgendaVisitaStatus.realizada) return AgendaVisitaStatus.realizada;
    return AgendaVisitaStatus.agendado;
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
        if (dataReuniaoFim != null)
          'data_reuniao_fim': dataReuniaoFim!.toIso8601String().split('T').first,
        if (horaFim != null && horaFim!.isNotEmpty) 'hora_fim': horaFim,
        if (localTexto != null && localTexto!.isNotEmpty) 'local_texto': localTexto,
        if (localLat != null) 'local_lat': localLat,
        if (localLng != null) 'local_lng': localLng,
        if (descricao != null && descricao!.isNotEmpty) 'descricao': descricao,
        if (municipioId != null) 'municipio_id': municipioId,
        'visivel_apoiadores': visivelApoiadores,
        'notificacao_profile_ids': notificacaoProfileIds,
        'agenda_status': agendaStatus,
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
    this.origemLugarNome,
    this.perfil,
    this.cargoAssessor,
  });

  final String nome;
  final DateTime dataNascimento;
  final String? telefone;
  final String? email;
  final String tipo; // 'apoiador' | 'assessor' | 'votante'
  final String refId;
  /// Cidade (ex.: coluna `cidade_nome` em apoiadores).
  final String? municipioNome;
  /// Procedência / «de onde é» (`apoiador_origem_lugares`).
  final String? origemLugarNome;
  /// Classificação do apoiador (ex.: Prefeita, Empresário).
  final String? perfil;
  /// Cargo em `profiles` (assessores / equipe).
  final String? cargoAssessor;

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
