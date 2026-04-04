import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/mapa/data/mt_municipios_coords.dart';

/// Garante que [municipios] tenha dados no Supabase.
/// Tenta, em ordem:
///   1. RPC `seed_municipios_mt_if_empty` (se a migration foi aplicada).
///   2. Insert direto client-side com os dados locais de [mt_municipios_coords.dart].
/// Em qualquer caso, ao final chama [syncMissingMunicipiosMtFromAppList] para alinhar
/// à lista IBGE atual (142 municípios), corrigir nomes antigos e inserir faltantes.
Future<void> ensureMunicipiosMtSeeded(SupabaseClient client) async {
  try {
    final probe = await client.from('municipios').select('id').limit(1);
    if ((probe as List).isEmpty) {
      try {
        await client.rpc('seed_municipios_mt_if_empty');
      } catch (_) {}
      final check = await client.from('municipios').select('id').limit(1);
      if ((check as List).isEmpty) {
        await _seedClientSide(client);
      }
    }
  } catch (_) {
    return;
  }

  await syncMissingMunicipiosMtFromAppList(client);
}

/// Corrige registro legado e insere municípios que existem em [listCidadesMTNomesNormalizados]
/// mas ainda não estão na tabela (ex.: base antiga com 138 linhas).
Future<void> syncMissingMunicipiosMtFromAppList(SupabaseClient client) async {
  try {
    try {
      await client.from('municipios').update({
        'nome': 'Araguainha',
        'nome_normalizado': 'araguainha',
      }).eq('nome_normalizado', 'araguanta');
    } catch (_) {}

    final polosRes = await client.from('polos_regioes').select('id, nome');
    final poloIdPorNome = <String, String>{};
    for (final raw in polosRes as List<dynamic>) {
      final r = raw as Map<String, dynamic>;
      final nome = r['nome'] as String?;
      final id = r['id'] as String?;
      if (nome != null && id != null) poloIdPorNome[nome] = id;
    }
    final poloPadrao = poloIdPorNome['Sinop'];
    if (poloPadrao == null) return;

    final munRes = await client.from('municipios').select('nome_normalizado');
    final existentes = <String>{
      for (final raw in munRes as List<dynamic>)
        ((raw as Map<String, dynamic>)['nome_normalizado'] as String?)?.toLowerCase() ?? '',
    }..remove('');

    String poloIdParaChave(String keyUpper) {
      switch (keyUpper) {
        case 'BOA ESPERANCA DO NORTE':
          return poloIdPorNome['Sinop'] ?? poloPadrao;
        case 'PONTAL DO ARAGUAIA':
        case 'PONTE BRANCA':
          return poloIdPorNome['Barra do Garças'] ?? poloPadrao;
        case 'VILA BELA DA SANTISSIMA TRINDADE':
          return poloIdPorNome['Cáceres'] ?? poloPadrao;
        default:
          return poloPadrao;
      }
    }

    final novos = <Map<String, dynamic>>[];
    for (final key in listCidadesMTNomesNormalizados) {
      final nn = key.toLowerCase();
      if (existentes.contains(nn)) continue;
      novos.add({
        'nome': displayNomeCidadeMT(key),
        'nome_normalizado': nn,
        'polo_id': poloIdParaChave(key),
      });
    }

    if (novos.isEmpty) return;

    await client.from('municipios').upsert(
      novos,
      onConflict: 'nome_normalizado',
    );
  } catch (_) {
    // Sem permissão de INSERT/UPDATE ou rede — lista do app segue limitada ao banco.
  }
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
