/// Formatação pt-BR sem `package:intl`, evitando `Intl.v8BreakIterator` no Flutter Web
/// (Chrome recente lança `UnimplementedError` / tela vermelha).
library;

String formatarInteiroPtBr(int n) {
  final negative = n < 0;
  final s = n.abs().toString();
  final buf = StringBuffer();
  final len = s.length;
  for (var i = 0; i < len; i++) {
    if (i > 0 && (len - i) % 3 == 0) {
      buf.write('.');
    }
    buf.write(s[i]);
  }
  final out = buf.toString();
  return negative ? '-$out' : out;
}

/// Ex.: 1234.56 → `R$ 1.234,56`
String formatarMoedaPtBr(double value) {
  final negative = value < 0;
  final abs = value.abs();
  final cents = (abs * 100).round();
  final intPart = cents ~/ 100;
  final frac = cents % 100;
  final intStr = formatarInteiroPtBr(intPart);
  final fracStr = frac.toString().padLeft(2, '0');
  if (negative) {
    return 'R\$ -$intStr,$fracStr';
  }
  return 'R\$ $intStr,$fracStr';
}

/// Aproximação de moeda compacta (rótulos no mapa), sem depender de `NumberFormat.compactCurrency`.
String formatarMoedaCompactaPtBr(double value) {
  if (value < 0) {
    return '-${formatarMoedaCompactaPtBr(-value)}';
  }
  final v = value;
  if (v >= 1e9) {
    return 'R\$ ${(v / 1e9).toStringAsFixed(1)} bi';
  }
  if (v >= 1e6) {
    return 'R\$ ${(v / 1e6).toStringAsFixed(1)} mi';
  }
  if (v >= 1e3) {
    return 'R\$ ${(v / 1e3).toStringAsFixed(1)} mil';
  }
  return formatarMoedaPtBr(value);
}

String formatarDataPtBr(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  final yyyy = d.year.toString();
  return '$dd/$mm/$yyyy';
}
