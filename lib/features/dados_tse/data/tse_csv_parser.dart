import 'package:csv/csv.dart';

/// Converte conteúdo CSV (TSE) em lista de mapas.
/// Aceita separador vírgula ou ponto-e-vírgula.
List<Map<String, dynamic>> parseTseCsv(String content) {
  List<List<dynamic>> rows;
  if (content.contains(';') && !content.contains(',') || content.split(';').length > content.split(',').length) {
    rows = const CsvToListConverter(fieldDelimiter: ';').convert(content);
  } else {
    rows = const CsvToListConverter().convert(content);
  }
  if (rows.isEmpty) return [];
  final headers = rows.first.map((e) => e.toString().trim()).toList();
  final result = <Map<String, dynamic>>[];
  for (var i = 1; i < rows.length; i++) {
    final row = rows[i];
    final map = <String, dynamic>{};
    for (var j = 0; j < headers.length && j < row.length; j++) {
      final key = headers[j];
      if (key.isEmpty) continue;
      map[key] = row[j]?.toString().trim() ?? '';
    }
    result.add(map);
  }
  return result;
}
