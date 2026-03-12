import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'regioes_mt.dart';

const _prefsKeyRegioesFundidas = 'mapa_regioes_fundidas';

/// Região fundida: várias regiões intermediárias agrupadas sob um único nome.
class RegiaoFundida {
  const RegiaoFundida({
    required this.id,
    required this.nome,
    required this.ids,
  });

  final String id;
  final String nome;
  final List<String> ids;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'ids': ids,
      };

  factory RegiaoFundida.fromJson(Map<String, dynamic> json) {
    return RegiaoFundida(
      id: json['id'] as String? ?? '',
      nome: json['nome'] as String? ?? '',
      ids: (json['ids'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
    );
  }
}

/// Região efetiva: uma região única ou um grupo fundido, para exibição em Metas/Responsáveis/Mapa.
class RegiaoEfetiva {
  const RegiaoEfetiva({
    required this.id,
    required this.nome,
    required this.ids,
    required this.cor,
    required this.descricao,
    this.eFundida = false,
    this.baseRegioes,
  });

  final String id;
  final String nome;
  final List<String> ids;
  final Color cor;
  final String descricao;
  final bool eFundida;
  /// Quando fornecido (regiões mapeadas), nomesOriginais usa esta lista em vez de regioesIntermediariasMT.
  final List<RegiaoMT>? baseRegioes;

  String get nomesOriginais {
    final base = baseRegioes ?? regioesIntermediariasMT;
    return ids.map((id) => base.where((r) => r.id == id).firstOrNull?.nome ?? id).join(' + ');
  }
}

/// Retorna o nome de exibição para um cdRgint (5101, 5102, ...) considerando fusões e nomes customizados.
String nomeRegiaoPorCdRgint(
  String cdRgint,
  List<RegiaoFundida> fundidas, {
  Map<String, String>? nomesCustomizados,
}) {
  for (final f in fundidas) {
    if (f.ids.contains(cdRgint)) return f.nome;
  }
  final custom = nomesCustomizados?[cdRgint];
  if (custom != null && custom.isNotEmpty) return custom;
  final r = regioesIntermediariasMT.where((e) => e.id == cdRgint).firstOrNull;
  return r?.nome ?? cdRgint;
}

/// Carrega lista de regiões fundidas do storage.
Future<List<RegiaoFundida>> loadRegioesFundidas() async {
  final prefs = await SharedPreferences.getInstance();
  final json = prefs.getString(_prefsKeyRegioesFundidas);
  if (json == null || json.isEmpty) return [];
  try {
    final list = jsonDecode(json) as List<dynamic>?;
    if (list == null) return [];
    return list.map((e) => RegiaoFundida.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
}

/// Salva lista de regiões fundidas.
Future<void> saveRegioesFundidas(List<RegiaoFundida> list) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _prefsKeyRegioesFundidas,
    jsonEncode(list.map((e) => e.toJson()).toList()),
  );
}

/// Nomes e cores customizados do mapa são persistidos no Supabase (mapa_regioes_custom) para todos os usuários; ver estrategia/data/mapa_custom_repository.dart.

/// Calcula as regiões efetivas: fusões primeiro, depois regiões que não estão em nenhuma fusão.
/// [baseRegioes] quando fornecido (ex.: regiões mapeadas do GeoJSON 2024), usa esta lista em vez das 5 intermediárias.
/// Resolve o nome de exibição de uma região: mesmo critério do mapa (id ou partKey "id#índice").
String nomeExibicaoRegiao(String id, String nomeOriginal, Map<String, String> nomesCustomizados) {
  final direct = nomesCustomizados[id]?.trim();
  if (direct != null && direct.isNotEmpty) return direct;
  for (final e in nomesCustomizados.entries) {
    if (e.key.startsWith('$id#') && e.value.trim().isNotEmpty) return e.value.trim();
  }
  return nomeOriginal;
}

/// [nomesCustomizados] aplica os nomes editados pelo usuário no mapa (por id ou partKey "id#índice").
List<RegiaoEfetiva> computeRegioesEfetivas(
  List<RegiaoFundida> fundidas, {
  List<RegiaoMT>? baseRegioes,
  Map<String, String> nomesCustomizados = const {},
}) {
  final base = baseRegioes ?? regioesIntermediariasMT;
  final covered = <String>{};
  for (final f in fundidas) {
    for (final id in f.ids) {
      covered.add(id);
    }
  }

  final result = <RegiaoEfetiva>[];

  for (final f in fundidas) {
    if (f.ids.isEmpty) continue;
    final firstId = f.ids.first;
    final baseReg = base.where((r) => r.id == firstId).firstOrNull;
    final cor = baseReg?.cor ?? Colors.grey;
    final desc = f.ids.length > 1
        ? '${f.ids.length} regiões fundidas: ${f.ids.map((id) => base.where((r) => r.id == id).firstOrNull?.nome ?? id).join(", ")}'
        : (baseReg?.descricao ?? '');
    result.add(RegiaoEfetiva(
      id: f.id,
      nome: f.nome,
      ids: f.ids,
      cor: cor,
      descricao: desc,
      eFundida: f.ids.length > 1,
      baseRegioes: baseRegioes,
    ));
  }

  for (final r in base) {
    if (covered.contains(r.id)) continue;
    final nomeExibicao = nomeExibicaoRegiao(r.id, r.nome, nomesCustomizados);
    result.add(RegiaoEfetiva(
      id: r.id,
      nome: nomeExibicao,
      ids: [r.id],
      cor: r.cor,
      descricao: r.descricao,
      eFundida: false,
      baseRegioes: baseRegioes,
    ));
  }

  return result;
}
