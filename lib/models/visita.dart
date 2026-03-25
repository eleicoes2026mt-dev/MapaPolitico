import 'package:intl/intl.dart';

class Visita {
  const Visita({
    required this.id,
    required this.titulo,
    required this.dataReuniao,
    this.hora,
    this.localTexto,
    this.descricao,
    this.municipioId,
    this.municipioNome,
    this.criadoPor,
    this.notificadosEm,
    this.visivelApoiadores = true,
  });

  final String id;
  final String titulo;
  final DateTime dataReuniao;
  final String? hora; // "HH:MM"
  final String? localTexto;
  final String? descricao;
  final String? municipioId;
  final String? municipioNome;
  final String? criadoPor;
  final DateTime? notificadosEm;
  final bool visivelApoiadores;

  bool get isFutura => dataReuniao.isAfter(DateTime.now().subtract(const Duration(days: 1)));
  bool get isHoje {
    final hoje = DateTime.now();
    return dataReuniao.year == hoje.year &&
        dataReuniao.month == hoje.month &&
        dataReuniao.day == hoje.day;
  }

  String get dataFormatada => DateFormat('dd/MM/yyyy').format(dataReuniao);
  String get horaFormatada => hora ?? '';
  String get dataHoraFormatada =>
      hora != null && hora!.isNotEmpty ? '$dataFormatada às $hora' : dataFormatada;

  factory Visita.fromJson(Map<String, dynamic> json) {
    final mun = json['municipios'];
    final munNome = mun is Map ? mun['nome']?.toString() : null;
    return Visita(
      id: json['id'] as String,
      titulo: json['titulo'] as String,
      dataReuniao: DateTime.parse(json['data_reuniao'] as String),
      hora: json['hora'] as String?,
      localTexto: json['local_texto'] as String?,
      descricao: json['descricao'] as String?,
      municipioId: json['municipio_id'] as String?,
      municipioNome: munNome,
      criadoPor: json['criado_por'] as String?,
      notificadosEm: json['notificados_em'] != null
          ? DateTime.tryParse(json['notificados_em'].toString())
          : null,
      visivelApoiadores: json['visivel_apoiadores'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'titulo': titulo,
        'data_reuniao': dataReuniao.toIso8601String().split('T').first,
        if (hora != null && hora!.isNotEmpty) 'hora': hora,
        if (localTexto != null && localTexto!.isNotEmpty) 'local_texto': localTexto,
        if (descricao != null && descricao!.isNotEmpty) 'descricao': descricao,
        if (municipioId != null) 'municipio_id': municipioId,
        'visivel_apoiadores': visivelApoiadores,
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

  String get whatsappUrl {
    if (telefone == null || telefone!.isEmpty) return '';
    final digits = telefone!.replaceAll(RegExp(r'[^\d]'), '');
    final ddi = digits.startsWith('55') ? digits : '55$digits';
    final msg = Uri.encodeComponent(
      'Olá $nome! 🎂 Feliz aniversário! Estamos juntos nessa caminhada. Abraços!',
    );
    return 'https://wa.me/$ddi?text=$msg';
  }
}
