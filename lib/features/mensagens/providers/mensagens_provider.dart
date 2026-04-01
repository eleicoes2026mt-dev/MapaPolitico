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
  final String escopo; // 'global' | 'polo' | 'cidade' | 'performance' | 'reuniao'
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

    // Envia push notification se solicitado
    if (p.enviarPush) {
      try {
        await supabase.functions.invoke('send-push', body: {
          'title': mensagem.titulo,
          'body': mensagem.corpo ?? 'Nova mensagem da campanha.',
          'url': '/#/mensagens',
          'tag': 'mensagem-${mensagem.id}',
        });
        // Marca como enviada
        await supabase
            .from('mensagens')
            .update({'enviada_em': DateTime.now().toIso8601String()})
            .eq('id', mensagem.id);
      } catch (_) {}
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

final enviarPushMensagemProvider = Provider<Future<void> Function(Mensagem)>((ref) {
  return (Mensagem m) async {
    await supabase.functions.invoke('send-push', body: {
      'title': m.titulo,
      'body': m.corpo ?? 'Nova mensagem da campanha.',
      'url': '/#/mensagens',
      'tag': 'mensagem-${m.id}',
    });
    await supabase
        .from('mensagens')
        .update({'enviada_em': DateTime.now().toIso8601String()})
        .eq('id', m.id);
    ref.invalidate(mensagensListProvider);
  };
});
