import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../models/apoiador.dart';

/// Parse de data no padrão dd/MM/yyyy; retorna null se inválido.
DateTime? parseDataDDMMYYYY(String? text) {
  if (text == null || text.trim().isEmpty) return null;
  var s = text.trim().replaceAll(RegExp(r'[^\d]'), '');
  if (s.length == 8) s = '${s.substring(0, 2)}/${s.substring(2, 4)}/${s.substring(4)}';
  if (s.length != 10) return null;
  try {
    return DateFormat('dd/MM/yyyy').parseStrict(s);
  } catch (_) {
    return null;
  }
}

/// Formata data ao digitar: dd/MM/yyyy.
class DataNascimentoInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length > 8) return oldValue;
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 2 || i == 4) buf.write('/');
      buf.write(digits[i]);
    }
    final s = buf.toString();
    return TextEditingValue(text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}

/// Formata telefone ao digitar: (00) 0 0000-0000 (11 dígitos: DDD + 9 + 8).
class TelefoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length > 11) return oldValue;
    if (digits.isEmpty) return newValue;
    String s;
    if (digits.length <= 2) {
      s = digits.isEmpty ? '' : '($digits';
    } else if (digits.length <= 7) {
      s = '(${digits.substring(0, 2)}) ${digits[2]} ${digits.substring(3)}';
    } else {
      s = '(${digits.substring(0, 2)}) ${digits[2]} ${digits.substring(3, 7)}-${digits.substring(7)}';
    }
    return TextEditingValue(text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}

String telefoneSoDigitos(String? s) => (s ?? '').replaceAll(RegExp(r'[^\d]'), '');

/// Formata valor ao digitar no padrão Real: 0.000,00
class ValorRealInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final t = newValue.text.replaceAll(RegExp(r'[^\d,]'), '');
    final commaIndex = t.indexOf(',');
    final onlyOneComma = commaIndex == -1 || commaIndex == t.lastIndexOf(',');
    if (!onlyOneComma) return oldValue;
    String intPart = commaIndex <= 0 ? t : t.substring(0, commaIndex);
    String decPart = commaIndex < 0 ? '' : t.substring(commaIndex + 1);
    if (decPart.length > 2) decPart = decPart.substring(0, 2);
    intPart = intPart.replaceFirst(RegExp(r'^0+'), '');
    if (intPart.isEmpty) intPart = '0';
    var intFormatted = '';
    for (var i = intPart.length; i > 0; i -= 3) {
      final start = (i - 3).clamp(0, intPart.length);
      final chunk = intPart.substring(start, i);
      intFormatted = intFormatted.isEmpty ? chunk : '$chunk.$intFormatted';
    }
    final decPadded = decPart.padRight(2, '0');
    final s = decPart.isEmpty && commaIndex < 0
        ? intFormatted
        : '$intFormatted,$decPadded';
    return TextEditingValue(text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}

double parseValorReal(String? text) {
  if (text == null || text.trim().isEmpty) return 0;
  final n = text.trim().replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(n) ?? 0;
}

int? parseLegado(String? text) {
  if (text == null || text.trim().isEmpty) return null;
  final n = int.tryParse(text.trim());
  return n != null && n >= 0 ? n : null;
}

final emailRegexApoiadores = RegExp(
  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
);

bool isEmailValido(String? s) => s != null && s.trim().isNotEmpty && emailRegexApoiadores.hasMatch(s.trim());

const perfisOpcoesApoiador = ['Prefeitural', 'Vereador(a)', 'Líder Religional', 'Empresarial'];

/// E-mail para convite (PF: email; PJ: e-mail do responsável).
String? emailParaConviteApoiador(Apoiador a) {
  for (final cand in [a.email, a.emailResponsavel]) {
    final s = cand?.trim() ?? '';
    if (s.isNotEmpty && emailRegexApoiadores.hasMatch(s)) return s;
  }
  return null;
}

const tiposBenfeitoriaLista = <(String, String)>[
  ('Obra', 'Obra'),
  ('Manutencao', 'Manutenção'),
  ('Ajuda_de_custo', 'Ajuda de custo'),
  ('Reforma', 'Reforma'),
  ('Doação', 'Doação'),
  ('Evento', 'Evento'),
  ('Outro', 'Outro'),
];
