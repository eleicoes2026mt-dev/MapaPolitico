import '../../../core/supabase/supabase_provider.dart';

/// Carrega nomes e cores customizadas do mapa a partir do Supabase (compartilhado entre todos os usuários).
Future<Map<String, String>> loadNomesCustomizadosFromSupabase() async {
  final res = await supabase.from('mapa_regioes_custom').select('cd_rgint, nome');
  final map = <String, String>{};
  for (final row in res as List) {
    final r = row as Map<String, dynamic>;
    final key = r['cd_rgint']?.toString();
    final nome = r['nome']?.toString();
    if (key != null && key.isNotEmpty && nome != null && nome.isNotEmpty) {
      map[key] = nome;
    }
  }
  return map;
}

/// Carrega cores customizadas do mapa a partir do Supabase.
Future<Map<String, String>> loadCoresCustomizadasFromSupabase() async {
  final res = await supabase.from('mapa_regioes_custom').select('cd_rgint, cor_hex');
  final map = <String, String>{};
  for (final row in res as List) {
    final r = row as Map<String, dynamic>;
    final key = r['cd_rgint']?.toString();
    final cor = r['cor_hex']?.toString();
    if (key != null && key.isNotEmpty && cor != null && cor.isNotEmpty) {
      map[key] = cor;
    }
  }
  return map;
}

/// Salva nome customizado de uma região; preserva a cor existente.
Future<void> saveNomeToSupabase(String cdRgint, String nome) async {
  final current = await supabase.from('mapa_regioes_custom').select('cor_hex').eq('cd_rgint', cdRgint).maybeSingle();
  final corHex = current?['cor_hex'] as String?;
  await supabase.from('mapa_regioes_custom').upsert(
    {'cd_rgint': cdRgint, 'nome': nome.trim().isEmpty ? null : nome.trim(), 'cor_hex': corHex},
    onConflict: 'cd_rgint',
  );
}

/// Salva cor customizada de uma região; preserva o nome existente.
Future<void> saveCorToSupabase(String cdRgint, String hexColor) async {
  final current = await supabase.from('mapa_regioes_custom').select('nome').eq('cd_rgint', cdRgint).maybeSingle();
  final nome = current?['nome'] as String?;
  await supabase.from('mapa_regioes_custom').upsert(
    {'cd_rgint': cdRgint, 'nome': nome, 'cor_hex': hexColor.trim().isEmpty ? null : hexColor.trim()},
    onConflict: 'cd_rgint',
  );
}

/// Restaura todos os nomes para o padrão (remove customizações de nome no Supabase). Preserva cores.
Future<void> clearAllNomesCustomizadosInSupabase() async {
  final res = await supabase.from('mapa_regioes_custom').select('cd_rgint, cor_hex');
  for (final row in res as List) {
    final r = row as Map<String, dynamic>;
    final key = r['cd_rgint']?.toString();
    if (key == null || key.isEmpty) continue;
    final corHex = r['cor_hex'] as String?;
    await supabase.from('mapa_regioes_custom').upsert(
      {'cd_rgint': key, 'nome': null, 'cor_hex': corHex},
      onConflict: 'cd_rgint',
    );
  }
}
