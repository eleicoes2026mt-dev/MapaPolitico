import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../../models/mensagem.dart';
import '../../auth/providers/auth_provider.dart';

// ── Listagem ──────────────────────────────────────────────────────────────────

final mensagensListProvider = FutureProvider<List<Mensagem>>((ref) async {
  final res = await supabase
      .from('mensagens')
      .select()
      .order('created_at', ascending: false);
  return (res as List<dynamic>).map((e) => Mensagem.fromJson(e as Map<String, dynamic>)).toList();
});

final mensagensCountProvider = FutureProvider<int>((ref) async {
  return ref.watch(mensagensListProvider).whenData((l) => l.length).valueOrNull ?? 0;
});

/// Polos regionais (abrangência «por polo»).
final polosRegioesListProvider = FutureProvider<List<({String id, String nome})>>((ref) async {
  final res = await supabase.from('polos_regioes').select('id, nome').order('nome');
  return (res as List)
      .map((e) => (id: e['id'].toString(), nome: e['nome'].toString()))
      .toList();
});

// ── Push: perfis alvo (send-push com profileIds) ─────────────────────────────

List<String> _uniqProfileIds(List<dynamic> rows, String key) {
  final out = <String>{};
  for (final e in rows) {
    if (e is! Map) continue;
    final id = e[key]?.toString();
    if (id != null && id.isNotEmpty) out.add(id);
  }
  return out.toList();
}

/// Resolve `profile_id` para envio segmentado; lista vazia = broadcast (send-push sem profileIds).
Future<List<String>> profileIdsParaNovaMensagem(NovaMensagemParams p) async {
  switch (p.escopo) {
    case 'global':
    case 'polo':
    case 'performance':
    case 'reuniao':
      return [];
    case 'privada_assessores':
      final r = await supabase.from('assessores').select('profile_id').eq('ativo', true);
      return _uniqProfileIds(r as List, 'profile_id');
    case 'privada_apoiadores':
      final r = await supabase.from('apoiadores').select('profile_id, excluido_em').not('profile_id', 'is', null);
      final rows = (r as List).where((e) => e is Map && e['excluido_em'] == null).toList();
      return _uniqProfileIds(rows, 'profile_id');
    case 'cidade':
      if (p.municipiosIds.isEmpty) return [];
      final ap = await supabase
          .from('apoiadores')
          .select('profile_id, excluido_em')
          .inFilter('municipio_id', p.municipiosIds)
          .not('profile_id', 'is', null);
      final apRows = (ap as List).where((e) => e is Map && e['excluido_em'] == null).toList();
      final vo = await supabase
          .from('votantes')
          .select('profile_id')
          .inFilter('municipio_id', p.municipiosIds)
          .not('profile_id', 'is', null);
      final set = <String>{}
        ..addAll(_uniqProfileIds(apRows, 'profile_id'))
        ..addAll(_uniqProfileIds(vo as List, 'profile_id'));
      return set.toList();
    default:
      return [];
  }
}

Future<List<String>> profileIdsParaMensagemExistente(Mensagem m) async {
  return profileIdsParaNovaMensagem(
    NovaMensagemParams(
      titulo: m.titulo,
      corpo: m.corpo,
      escopo: m.escopo,
      poloId: m.poloId,
      municipiosIds: m.municipiosIds,
      enviarPush: false,
    ),
  );
}

bool _escopoPushBroadcast(String escopo) =>
    escopo == 'global' || escopo == 'polo' || escopo == 'performance' || escopo == 'reuniao';

// ── Criação ───────────────────────────────────────────────────────────────────

class NovaMensagemParams {
  const NovaMensagemParams({
    required this.titulo,
    this.corpo,
    this.escopo = 'global',
    this.poloId,
    this.municipiosIds = const [],
    this.enviarPush = false,
  });

  final String titulo;
  final String? corpo;
  final String escopo;
  final String? poloId;
  final List<String> municipiosIds;
  final bool enviarPush;
}

final criarMensagemProvider = Provider<Future<Mensagem> Function(NovaMensagemParams)>((ref) {
  return (NovaMensagemParams p) async {
    final userId = ref.read(currentUserProvider)?.id;

    final row = {
      'titulo': p.titulo.trim(),
      if (p.corpo != null && p.corpo!.trim().isNotEmpty) 'corpo': p.corpo!.trim(),
      'escopo': p.escopo,
      if (p.poloId != null) 'polo_id': p.poloId,
      if (p.municipiosIds.isNotEmpty) 'municipios_ids': p.municipiosIds,
      'criado_por': userId,
    };

    final res = await supabase.from('mensagens').insert(row).select().single();
    final mensagem = Mensagem.fromJson(res);

    if (p.enviarPush) {
      final ids = await profileIdsParaNovaMensagem(p);
      if (!_escopoPushBroadcast(p.escopo) && ids.isEmpty) {
        throw Exception(
          'Nenhum destinatário com conta no app para este escopo. Verifique cadastros (perfil vinculado) e filtros.',
        );
      }
      await supabase.auth.refreshSession();
      final body = <String, dynamic>{
        'title': mensagem.titulo,
        'body': mensagem.corpo ?? 'Nova mensagem da campanha.',
        'url': '/#/mensagens',
        'tag': 'mensagem-${mensagem.id}',
      };
      if (ids.isNotEmpty) {
        body['profileIds'] = ids;
      }
      final r = await supabase.functions.invoke('send-push', body: body);
      if (r.status < 400) {
        await supabase
            .from('mensagens')
            .update({'enviada_em': DateTime.now().toIso8601String()})
            .eq('id', mensagem.id);
      }
    }

    ref.invalidate(mensagensListProvider);
    return mensagem;
  };
});

// ── Exclusão ──────────────────────────────────────────────────────────────────

final excluirMensagemProvider = Provider<Future<void> Function(String id)>((ref) {
  return (String id) async {
    await supabase.from('mensagens').delete().eq('id', id);
    ref.invalidate(mensagensListProvider);
  };
});

// ── Enviar push de mensagem existente ─────────────────────────────────────────

/// Retorna `{'sent': N, 'failed': N, 'total': N}` em caso de sucesso.
/// Lança [Exception] com mensagem legível em caso de erro.
final enviarPushMensagemProvider = Provider<Future<Map<String, dynamic>> Function(Mensagem)>((ref) {
  return (Mensagem m) async {
    final ids = await profileIdsParaMensagemExistente(m);
    if (!_escopoPushBroadcast(m.escopo) && ids.isEmpty) {
      throw Exception(
        'Nenhum destinatário com conta no app para este escopo. Verifique cadastros.',
      );
    }
    await supabase.auth.refreshSession();
    final body = <String, dynamic>{
      'title': m.titulo,
      'body': m.corpo ?? 'Nova mensagem da campanha.',
      'url': '/#/mensagens',
      'tag': 'mensagem-${m.id}',
    };
    if (ids.isNotEmpty) {
      body['profileIds'] = ids;
    }
    final res = await supabase.functions.invoke('send-push', body: body);

    if (res.status >= 400) {
      final detail = res.data is Map ? (res.data as Map)['error'] ?? res.data.toString() : res.data?.toString() ?? '';
      throw Exception('Erro ${res.status}: $detail');
    }

    await supabase
        .from('mensagens')
        .update({'enviada_em': DateTime.now().toIso8601String()})
        .eq('id', m.id);
    ref.invalidate(mensagensListProvider);

    return res.data is Map<String, dynamic>
        ? res.data as Map<String, dynamic>
        : {'sent': 0, 'failed': 0, 'total': 0};
  };
});
