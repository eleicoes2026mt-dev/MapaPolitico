import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/mapa/data/mt_municipios_coords.dart';

/// Garante que [municipios] tenha dados no Supabase.
/// Tenta, em ordem:
///   1. RPC `seed_municipios_mt_if_empty` (se a migration foi aplicada).
///   2. Insert direto client-side com os dados locais de [mt_municipios_coords.dart].
/// Sem efeito se já houver linhas; silencioso em caso de falha de permissão.
Future<void> ensureMunicipiosMtSeeded(SupabaseClient client) async {
  try {
    final probe = await client.from('municipios').select('id').limit(1);
    if ((probe as List).isNotEmpty) return;
  } catch (_) {
    return;
  }

  // Tentativa 1: RPC (migration aplicada no banco)
  try {
    await client.rpc('seed_municipios_mt_if_empty');
    final check = await client.from('municipios').select('id').limit(1);
    if ((check as List).isNotEmpty) return;
  } catch (_) {}

  // Tentativa 2: insert client-side (requer migration 20250329140000)
  await _seedClientSide(client);
}

Future<void> _seedClientSide(SupabaseClient client) async {
  try {
    // Upsert os 5 polos de referência
    await client.from('polos_regioes').upsert(
      [
        {'nome': 'Cuiabá', 'cor_hex': '#2196F3', 'ordem': 1, 'descricao': 'Centro-Sul'},
        {'nome': 'Rondonópolis', 'cor_hex': '#F44336', 'ordem': 2, 'descricao': 'Sudeste'},
        {'nome': 'Sinop', 'cor_hex': '#4CAF50', 'ordem': 3, 'descricao': 'Norte'},
        {'nome': 'Barra do Garças', 'cor_hex': '#FF9800', 'ordem': 4, 'descricao': 'Leste'},
        {'nome': 'Cáceres', 'cor_hex': '#9C27B0', 'ordem': 5, 'descricao': 'Sudoeste/Oeste'},
      ],
      onConflict: 'nome',
    );

    // Busca o ID do polo Sinop (polo padrão para todos os municípios no seed rápido)
    final sinopRes = await client
        .from('polos_regioes')
        .select('id')
        .eq('nome', 'Sinop')
        .maybeSingle();
    final sinopId = sinopRes?['id'] as String?;
    if (sinopId == null) return;

    // Insere todos os municípios de MT a partir da lista local do app
    final muns = listCidadesMTNomesNormalizados.map((key) {
      return {
        'nome': displayNomeCidadeMT(key),
        'nome_normalizado': key.toLowerCase(),
        'polo_id': sinopId,
      };
    }).toList();

    await client.from('municipios').upsert(
      muns,
      onConflict: 'nome_normalizado',
    );
  } catch (_) {
    // Falha silenciosa (sem policy de INSERT ainda) — app segue com cidade_nome.
  }
}
