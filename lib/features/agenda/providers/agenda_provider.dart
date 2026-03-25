import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../../models/visita.dart';
import '../../apoiadores/providers/apoiadores_provider.dart';
import '../../auth/providers/auth_provider.dart';

// ── Visitas ──────────────────────────────────────────────────────────────────

/// Todas as visitas futuras (candidato + assessor).
final visitasProvider = FutureProvider<List<Visita>>((ref) async {
  final res = await supabase
      .from('reunioes')
      .select('*, municipios(nome)')
      .gte('data_reuniao', DateTime.now().subtract(const Duration(days: 1)).toIso8601String().split('T').first)
      .order('data_reuniao');
  return (res as List).map((e) => Visita.fromJson(e)).toList();
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
  final res = await supabase
      .from('reunioes')
      .select('*, municipios(nome)')
      .eq('municipio_id', municipioId)
      .eq('visivel_apoiadores', true)
      .gte('data_reuniao', hoje)
      .order('data_reuniao')
      .limit(1)
      .maybeSingle();

  if (res == null) return null;
  return Visita.fromJson(res);
});

// ── CRUD visitas ──────────────────────────────────────────────────────────────

class NovaVisitaParams {
  const NovaVisitaParams({
    required this.titulo,
    required this.dataReuniao,
    this.hora,
    this.localTexto,
    this.descricao,
    this.municipioId,
    this.visivelApoiadores = true,
  });

  final String titulo;
  final DateTime dataReuniao;
  final String? hora;
  final String? localTexto;
  final String? descricao;
  final String? municipioId;
  final bool visivelApoiadores;
}

final criarVisitaProvider = Provider<Future<void> Function(NovaVisitaParams)>((ref) {
  return (NovaVisitaParams p) async {
    final user = ref.read(currentUserProvider);
    await supabase.from('reunioes').insert({
      'titulo': p.titulo.trim(),
      if (p.hora != null && p.hora!.isNotEmpty) 'hora': p.hora,
      'data_reuniao': p.dataReuniao.toIso8601String().split('T').first,
      if (p.localTexto != null && p.localTexto!.isNotEmpty) 'local_texto': p.localTexto!.trim(),
      if (p.descricao != null && p.descricao!.isNotEmpty) 'descricao': p.descricao!.trim(),
      if (p.municipioId != null) 'municipio_id': p.municipioId,
      'visivel_apoiadores': p.visivelApoiadores,
      'criado_por': user?.id,
    });
    ref.invalidate(visitasProvider);
    ref.invalidate(todasVisitasProvider);
    ref.invalidate(proximaVisitaMinhaCidadeProvider);
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
      'descricao': p.descricao?.trim().isEmpty == true ? null : p.descricao?.trim(),
      'municipio_id': p.municipioId,
      'visivel_apoiadores': p.visivelApoiadores,
    }).eq('id', id);
    ref.invalidate(visitasProvider);
    ref.invalidate(todasVisitasProvider);
    ref.invalidate(proximaVisitaMinhaCidadeProvider);
  };
});

final excluirVisitaProvider = Provider<Future<void> Function(String id)>((ref) {
  return (String id) async {
    await supabase.from('reunioes').delete().eq('id', id);
    ref.invalidate(visitasProvider);
    ref.invalidate(todasVisitasProvider);
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
        .select('id, nome, data_nascimento, telefone, email')
        .not('data_nascimento', 'is', null);
    for (final e in res as List) {
      final m = e as Map<String, dynamic>;
      final dt = DateTime.tryParse(m['data_nascimento'].toString());
      if (dt == null) continue;
      lista.add(Aniversariante(
        nome: m['nome'] as String,
        dataNascimento: dt,
        telefone: m['telefone'] as String?,
        email: m['email'] as String?,
        tipo: 'apoiador',
        refId: m['id'] as String,
      ));
    }
  } catch (_) {}

  // Assessores (via profiles)
  try {
    final res = await supabase
        .from('profiles')
        .select('id, full_name, phone, data_nascimento')
        .eq('role', 'assessor')
        .not('data_nascimento', 'is', null);
    for (final e in res as List) {
      final m = e as Map<String, dynamic>;
      final dt = DateTime.tryParse(m['data_nascimento'].toString());
      if (dt == null) continue;
      lista.add(Aniversariante(
        nome: m['full_name'] as String? ?? 'Assessor',
        dataNascimento: dt,
        telefone: m['phone'] as String?,
        tipo: 'assessor',
        refId: m['id'] as String,
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
