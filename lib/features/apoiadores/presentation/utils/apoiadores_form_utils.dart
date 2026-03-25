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

/// Celular: (DD) 9 NNNN-NNNN — até 11 dígitos. Fixo: (DD) NNNN-NNNN — até 10 dígitos.
/// Se o 3.º dígito for 9, assume celular; caso contrário, fixo.
String _formatMobileBr(String digits) {
  if (digits.isEmpty) return '';
  if (digits.length == 1) return '($digits';
  if (digits.length == 2) return '($digits)';
  final dd = digits.substring(0, 2);
  final rest = digits.substring(2);
  if (rest.length == 1) return '($dd) $rest';
  if (rest.length <= 5) return '($dd) ${rest[0]} ${rest.substring(1)}';
  return '($dd) ${rest[0]} ${rest.substring(1, 5)}-${rest.substring(5)}';
}

String _formatLandlineBr(String digits) {
  if (digits.isEmpty) return '';
  if (digits.length == 1) return '($digits';
  if (digits.length == 2) return '($digits)';
  final dd = digits.substring(0, 2);
  final rest = digits.substring(2);
  if (rest.length <= 4) return '($dd) $rest';
  return '($dd) ${rest.substring(0, 4)}-${rest.substring(4)}';
}

/// Exibe telefone a partir só de dígitos (ex.: valor vindo do banco).
String formatTelefoneBrFromDigits(String? stored) {
  final d = telefoneSoDigitos(stored);
  if (d.isEmpty) return '';
  final mobile = d.length >= 3 && d[2] == '9';
  return mobile ? _formatMobileBr(d) : _formatLandlineBr(d);
}

/// Formata telefone ao digitar: (00) 0 0000-0000 (celular) ou (00) 0000-0000 (fixo).
class TelefoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return newValue;
    final mobile = digits.length >= 3 && digits[2] == '9';
    final maxLen = mobile ? 11 : 10;
    if (digits.length > maxLen) return oldValue;
    final s = mobile ? _formatMobileBr(digits) : _formatLandlineBr(digits);
    return TextEditingValue(text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}

/// CEP: 00000-000
class CepInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length > 8) return oldValue;
    if (digits.isEmpty) return newValue;
    final s =
        digits.length <= 5 ? digits : '${digits.substring(0, 5)}-${digits.substring(5)}';
    return TextEditingValue(text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}

/// Exibe CEP a partir de até 8 dígitos.
String formatCepDisplayFromDigits(String? stored) {
  final d = (stored ?? '').replaceAll(RegExp(r'[^\d]'), '');
  if (d.length <= 5) return d;
  if (d.length <= 8) return '${d.substring(0, 5)}-${d.substring(5)}';
  return '${d.substring(0, 5)}-${d.substring(5, 8)}';
}

String cepSoDigitos(String? s) => (s ?? '').replaceAll(RegExp(r'[^\d]'), '');

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
