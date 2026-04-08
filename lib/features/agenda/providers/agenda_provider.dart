import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../../models/visita.dart';
import '../../apoiadores/providers/apoiadores_provider.dart';
import '../../auth/providers/auth_provider.dart';

/// Perfis (auth) com apoiador ou votante neste município — para push segmentado por cidade.
Future<List<String>> profileIdsMoradoresCidadeComConta(String municipioId) async {
  if (municipioId.isEmpty) return [];
  final ids = <String>{};
  try {
    final a = await supabase
        .from('apoiadores')
        .select('profile_id')
        .eq('municipio_id', municipioId)
        .eq('ativo', true)
        .not('profile_id', 'is', null);
    for (final e in a as List) {
      final pid = e['profile_id'] as String?;
      if (pid != null && pid.isNotEmpty) ids.add(pid);
    }
  } catch (_) {}
  try {
    final v = await supabase
        .from('votantes')
        .select('profile_id')
        .eq('municipio_id', municipioId)
        .not('profile_id', 'is', null);
    for (final e in v as List) {
      final pid = e['profile_id'] as String?;
      if (pid != null && pid.isNotEmpty) ids.add(pid);
    }
  } catch (_) {}
  return ids.toList();
}

// ── Visitas ──────────────────────────────────────────────────────────────────

List<Map<String, dynamic>> _mergeReunioesPorId(List<dynamic> a, List<dynamic> b) {
  final map = <String, Map<String, dynamic>>{};
  for (final e in a) {
    final m = Map<String, dynamic>.from(e as Map);
    map[m['id'] as String] = m;
  }
  for (final e in b) {
    final m = Map<String, dynamic>.from(e as Map);
    map[m['id'] as String] = m;
  }
  return map.values.toList();
}

/// Todas as visitas futuras (candidato + assessor + apoiador com regras de visibilidade).
final visitasProvider = FutureProvider<List<Visita>>((ref) async {
  final profile = await ref.read(profileProvider.future);
  final hoje = DateTime.now().subtract(const Duration(days: 1)).toIso8601String().split('T').first;

  if (profile?.role == 'apoiador') {
    final pid = profile!.id;
    final res1 = await supabase
        .from('reunioes')
        .select('*, municipios(nome)')
        .eq('visivel_apoiadores', true)
        .gte('data_reuniao', hoje)
        .order('data_reuniao');
    final res2 = await supabase
        .from('reunioes')
        .select('*, municipios(nome)')
        .contains('notificacao_profile_ids', [pid])
        .gte('data_reuniao', hoje)
        .order('data_reuniao');
    final merged = _mergeReunioesPorId(res1 as List, res2 as List);
    merged.sort((a, b) => a['data_reuniao'].toString().compareTo(b['data_reuniao'].toString()));
    return merged.map((e) => Visita.fromJson(e)).toList();
  }

  final res = await supabase
      .from('reunioes')
      .select('*, municipios(nome)')
      .gte('data_reuniao', hoje)
      .order('data_reuniao');
  return (res as List).map((e) => Visita.fromJson(e as Map<String, dynamic>)).toList();
});

/// Visitas TODAS (incluindo passadas) para o calendário.
final todasVisitasProvider = FutureProvider<List<Visita>>((ref) async {
  final res = await supabase
      .from('reunioes')
      .select('*, municipios(nome)')
      .order('data_reuniao');
  return (res as List).map((e) => Visita.fromJson(e)).toList();
});

/// Próxima visita à cidade do apoiador logado (para banner).
final proximaVisitaMinhaCidadeProvider = FutureProvider<Visita?>((ref) async {
  final profile = await ref.read(profileProvider.future);
  if (profile == null || profile.role != 'apoiador') return null;

  final apoiador = ref.read(meuApoiadorProvider).valueOrNull;
  final municipioId = apoiador?.municipioId;
  if (municipioId == null || municipioId.isEmpty) return null;

  final hoje = DateTime.now().toIso8601String().split('T').first;
  final res1 = await supabase
      .from('reunioes')
      .select('*, municipios(nome)')
      .eq('municipio_id', municipioId)
      .eq('visivel_apoiadores', true)
      .gte('data_reuniao', hoje)
      .order('data_reuniao')
      .limit(1)
      .maybeSingle();

  final res2 = await supabase
      .from('reunioes')
      .select('*, municipios(nome)')
      .eq('municipio_id', municipioId)
      .contains('notificacao_profile_ids', [profile.id])
      .gte('data_reuniao', hoje)
      .order('data_reuniao')
      .limit(1)
      .maybeSingle();

  if (res1 == null && res2 == null) return null;
  if (res1 == null) return Visita.fromJson(Map<String, dynamic>.from(res2 as Map));
  if (res2 == null) return Visita.fromJson(Map<String, dynamic>.from(res1 as Map));
  final v1 = Visita.fromJson(Map<String, dynamic>.from(res1 as Map));
  final v2 = Visita.fromJson(Map<String, dynamic>.from(res2 as Map));
  if (v1.dataReuniao.isBefore(v2.dataReuniao)) return v1;
  if (v2.dataReuniao.isBefore(v1.dataReuniao)) return v2;
  return v1;
});

/// Primeira visita futura visível ainda sem confirmação de presença (apoiador: só da cidade).
final visitaPendenteConfirmacaoProvider = FutureProvider<Visita?>((ref) async {
  final profile = await ref.read(profileProvider.future);
  if (profile == null) return null;
  final role = profile.role;
  if (role != 'apoiador' && role != 'assessor') return null;

  final hoje = DateTime.now().toIso8601String().split('T').first;
  late List<Map<String, dynamic>> rows;

  if (role == 'apoiador') {
    final apoiador = await ref.watch(meuApoiadorProvider.future);
    final mid = apoiador?.municipioId;
    if (mid == null || mid.isEmpty) return null;
    final rows1 = await supabase
        .from('reunioes')
        .select('*, municipios(nome)')
        .eq('municipio_id', mid)
        .eq('visivel_apoiadores', true)
        .gte('data_reuniao', hoje)
        .order('data_reuniao')
        .limit(25);
    final rows2 = await supabase
        .from('reunioes')
        .select('*, municipios(nome)')
        .eq('municipio_id', mid)
        .contains('notificacao_profile_ids', [profile.id])
        .gte('data_reuniao', hoje)
        .order('data_reuniao')
        .limit(25);
    rows = _mergeReunioesPorId(rows1 as List, rows2 as List);
    rows.sort((a, b) => a['data_reuniao'].toString().compareTo(b['data_reuniao'].toString()));
  } else {
    final rows1 = await supabase
        .from('reunioes')
        .select('*, municipios(nome)')
        .eq('visivel_apoiadores', true)
        .gte('data_reuniao', hoje)
        .order('data_reuniao')
        .limit(25);
    final rows2 = await supabase
        .from('reunioes')
        .select('*, municipios(nome)')
        .contains('notificacao_profile_ids', [profile.id])
        .gte('data_reuniao', hoje)
        .order('data_reuniao')
        .limit(25);
    rows = _mergeReunioesPorId(rows1 as List, rows2 as List);
    rows.sort((a, b) => a['data_reuniao'].toString().compareTo(b['data_reuniao'].toString()));
  }

  if (rows.isEmpty) return null;

  final presRes = await supabase.from('reunioes_presenca').select('reuniao_id').eq('profile_id', profile.id);
  final confirmed = (presRes as List).map((e) => e['reuniao_id'] as String).toSet();

  for (final r in rows) {
    final m = Map<String, dynamic>.from(r);
    final id = m['id'] as String;
    if (!confirmed.contains(id)) return Visita.fromJson(m);
  }
  return null;
});

// ── CRUD visitas ──────────────────────────────────────────────────────────────

class NovaVisitaParams {
  const NovaVisitaParams({
    required this.titulo,
    required this.dataReuniao,
    this.hora,
    this.localTexto,
    this.localLat,
    this.localLng,
    this.descricao,
    this.municipioId,
    this.visivelApoiadores = true,
    this.notificacaoProfileIds = const [],
    /// Se true (visita pública com cidade), o push inicial usa só contas na cidade em vez de broadcast.
    this.pushApenasMoradoresDaCidade = false,
  });

  final String titulo;
  final DateTime dataReuniao;
  final String? hora;
  final String? localTexto;
  final double? localLat;
  final double? localLng;
  final String? descricao;
  final String? municipioId;
  final bool visivelApoiadores;
  final List<String> notificacaoProfileIds;
  final bool pushApenasMoradoresDaCidade;
}

final criarVisitaProvider = Provider<Future<void> Function(NovaVisitaParams)>((ref) {
  return (NovaVisitaParams p) async {
    final user = ref.read(currentUserProvider);
    final res = await supabase.from('reunioes').insert({
      'titulo': p.titulo.trim(),
      if (p.hora != null && p.hora!.isNotEmpty) 'hora': p.hora,
      'data_reuniao': p.dataReuniao.toIso8601String().split('T').first,
      if (p.localTexto != null && p.localTexto!.isNotEmpty) 'local_texto': p.localTexto!.trim(),
      'local_lat': p.localLat,
      'local_lng': p.localLng,
      if (p.descricao != null && p.descricao!.isNotEmpty) 'descricao': p.descricao!.trim(),
      if (p.municipioId != null) 'municipio_id': p.municipioId,
      'visivel_apoiadores': p.visivelApoiadores,
      'notificacao_profile_ids': p.notificacaoProfileIds,
      'criado_por': user?.id,
    }).select('id, titulo, local_texto').maybeSingle();

    // Push: público = broadcast (sem profileIds); privado = só destinatários
    if (res != null && (p.visivelApoiadores || p.notificacaoProfileIds.isNotEmpty)) {
      try {
        await supabase.auth.refreshSession();
        final titulo = res['titulo'] as String? ?? p.titulo;
        final local = res['local_texto'] as String? ?? p.localTexto ?? '';
        final dataStr = p.dataReuniao.toIso8601String().split('T').first;
        final body = <String, dynamic>{
          'title': '📅 Nova visita agendada',
          'body': '$titulo — $dataStr${local.isNotEmpty ? " • $local" : ""}',
          'url': '/#/agenda',
          'tag': 'visita-${res['id']}',
        };
        var enviarPush = true;
        if (!p.visivelApoiadores && p.notificacaoProfileIds.isNotEmpty) {
          body['profileIds'] = p.notificacaoProfileIds;
        } else if (p.visivelApoiadores &&
            p.pushApenasMoradoresDaCidade &&
            p.municipioId != null &&
            p.municipioId!.isNotEmpty) {
          final alvo = await profileIdsMoradoresCidadeComConta(p.municipioId!);
          if (alvo.isEmpty) {
            enviarPush = false;
          } else {
            body['profileIds'] = alvo;
          }
        }
        if (enviarPush) {
          await supabase.functions.invoke('send-push', body: body);
        }
      } catch (_) {}
    }

    ref.invalidate(visitasProvider);
    ref.invalidate(todasVisitasProvider);
    ref.invalidate(proximaVisitaMinhaCidadeProvider);
    ref.invalidate(visitaPendenteConfirmacaoProvider);
  };
});

final atualizarVisitaProvider =
    Provider<Future<void> Function(String id, NovaVisitaParams p)>((ref) {
  return (String id, NovaVisitaParams p) async {
    await supabase.from('reunioes').update({
      'titulo': p.titulo.trim(),
      'hora': p.hora?.isNotEmpty == true ? p.hora : null,
      'data_reuniao': p.dataReuniao.toIso8601String().split('T').first,
      'local_texto': p.localTexto?.trim().isEmpty == true ? null : p.localTexto?.trim(),
      'local_lat': p.localLat,
      'local_lng': p.localLng,
      'descricao': p.descricao?.trim().isEmpty == true ? null : p.descricao?.trim(),
      'municipio_id': p.municipioId,
      'visivel_apoiadores': p.visivelApoiadores,
      'notificacao_profile_ids': p.notificacaoProfileIds,
    }).eq('id', id);
    ref.invalidate(visitasProvider);
    ref.invalidate(todasVisitasProvider);
    ref.invalidate(proximaVisitaMinhaCidadeProvider);
    ref.invalidate(visitaPendenteConfirmacaoProvider);
  };
});

final excluirVisitaProvider = Provider<Future<void> Function(String id)>((ref) {
  return (String id) async {
    await supabase.from('reunioes').delete().eq('id', id);
    ref.invalidate(visitasProvider);
    ref.invalidate(todasVisitasProvider);
    ref.invalidate(proximaVisitaMinhaCidadeProvider);
    ref.invalidate(visitaPendenteConfirmacaoProvider);
  };
});

// ── Aniversariantes ──────────────────────────────────────────────────────────

/// Aniversariantes dos próximos [diasAdianteParaProximos] dias
/// montados a partir de apoiadores, assessores e votantes com data_nascimento.
final aniversariantesProvider = FutureProvider<List<Aniversariante>>((ref) async {
  final List<Aniversariante> lista = [];

  // Apoiadores
  try {
    final res = await supabase
        .from('apoiadores')
        .select(
          'id, nome, data_nascimento, telefone, email, perfil, cidade_nome, '
          'origem_lugar:apoiador_origem_lugares!apoiadores_origem_lugar_id_fkey(nome)',
        )
        .not('data_nascimento', 'is', null);
    for (final e in res as List) {
      final m = e as Map<String, dynamic>;
      final dt = DateTime.tryParse(m['data_nascimento'].toString());
      if (dt == null) continue;
      final ol = m['origem_lugar'];
      String? origemNome;
      if (ol is Map && ol['nome'] != null) {
        origemNome = (ol['nome'] as String).trim();
      }
      final perfilRaw = m['perfil'] as String?;
      final perfilTrim = perfilRaw?.trim();
      final cidadeRaw = m['cidade_nome'] as String?;
      lista.add(Aniversariante(
        nome: m['nome'] as String,
        dataNascimento: dt,
        telefone: m['telefone'] as String?,
        email: m['email'] as String?,
        tipo: 'apoiador',
        refId: m['id'] as String,
        municipioNome:
            cidadeRaw != null && cidadeRaw.trim().isNotEmpty ? cidadeRaw.trim() : null,
        origemLugarNome: origemNome,
        perfil: perfilTrim != null && perfilTrim.isNotEmpty ? perfilTrim : null,
      ));
    }
  } catch (_) {}

  // Assessores (via profiles)
  try {
    final res = await supabase
        .from('profiles')
        .select('id, full_name, phone, data_nascimento, cargo')
        .eq('role', 'assessor')
        .not('data_nascimento', 'is', null);
    for (final e in res as List) {
      final m = e as Map<String, dynamic>;
      final dt = DateTime.tryParse(m['data_nascimento'].toString());
      if (dt == null) continue;
      final cargoRaw = m['cargo'] as String?;
      final cargoTrim = cargoRaw?.trim();
      lista.add(Aniversariante(
        nome: m['full_name'] as String? ?? 'Assessor',
        dataNascimento: dt,
        telefone: m['phone'] as String?,
        tipo: 'assessor',
        refId: m['id'] as String,
        cargoAssessor:
            cargoTrim != null && cargoTrim.isNotEmpty ? cargoTrim : null,
      ));
    }
  } catch (_) {}

  // Votantes (se tiver data_nascimento — campo pode não existir ainda)
  // Não incluídos por ora para não causar erro de coluna inexistente.

  lista.sort((a, b) => a.diasParaAniversario.compareTo(b.diasParaAniversario));
  return lista;
});

final aniversariantesHojeProvider = Provider<AsyncValue<List<Aniversariante>>>((ref) {
  return ref.watch(aniversariantesProvider).whenData(
        (lista) => lista.where((a) => a.isHoje).toList(),
      );
});

final aniversariantesProximos30Provider = Provider<AsyncValue<List<Aniversariante>>>((ref) {
  return ref.watch(aniversariantesProvider).whenData(
        (lista) =>
            lista.where((a) => !a.isHoje && a.diasParaAniversario <= 30).toList(),
      );
});
