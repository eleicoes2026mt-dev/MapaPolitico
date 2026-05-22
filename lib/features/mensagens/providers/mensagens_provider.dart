import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../../models/mensagem.dart';
import '../../../models/votante.dart';
import '../../apoiadores/providers/apoiadores_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../votantes/providers/votantes_provider.dart';

// ── Listagem ──────────────────────────────────────────────────────────────────

final mensagensListProvider = FutureProvider<List<Mensagem>>((ref) async {
  final res = await supabase
      .from('mensagens')
      .select()
      .order('created_at', ascending: false);
  return (res as List<dynamic>).map((e) => Mensagem.fromJson(e as Map<String, dynamic>)).toList();
});

/// Espelha abrangência para apoiador/votante. Candidato e assessores veem sempre
/// toda a lista devolvida pela API (equipe da campanha). Quem não é gestor
/// continua a ver o que criou (`criado_por`), mesmo que o escopo não inclua o papel.
final mensagensVisiveisParaUsuarioProvider = FutureProvider<List<Mensagem>>((ref) async {
  final profile = await ref.watch(profileProvider.future);
  final todas = await ref.watch(mensagensListProvider.future);
  if (profile == null) return [];

  if (profile.isCandidato || profile.isAssessor) {
    return todas;
  }

  final role = profile.role.trim().toLowerCase();

  bool enviadaPorMim(Mensagem m) =>
      m.criadoPor != null && m.criadoPor!.trim().isNotEmpty && m.criadoPor == profile.id;

  if (role == 'apoiador') {
    final ap = await ref.watch(meuApoiadorProvider.future);
    final municipioId = ap?.municipioId;
    final perfilApoiador = ap?.perfil;
    return todas
        .where((m) =>
            enviadaPorMim(m) ||
            mensagemVisivelParaApoiador(m, municipioId, perfilApoiador))
        .toList();
  }
  if (role == 'votante') {
    final vts = await ref.watch(votantesListProvider.future);
    return todas
        .where((m) => enviadaPorMim(m) || mensagemVisivelParaVotante(m, vts))
        .toList();
  }

  // Papel inesperado: não esconder no cliente (RLS é a fonte de verdade).
  return todas;
});

/// Critério alinhado a `mensagens_apoiador_read` (Supabase).
bool mensagemVisivelParaApoiador(
  Mensagem m,
  String? municipioIdUsuario,
  String? perfilCadastroApoiador,
) {
  switch (m.escopo) {
    case 'global':
    case 'polo':
    case 'performance':
    case 'reuniao':
    case 'privada_apoiadores':
      return true;
    case 'cidade':
      if (municipioIdUsuario == null || municipioIdUsuario.isEmpty) return false;
      if (m.municipiosIds.isEmpty) return false;
      return m.municipiosIds.contains(municipioIdUsuario);
    case 'apoiador_classificacao':
      final alvo = m.classificacaoApoiador?.trim();
      if (alvo == null || alvo.isEmpty) return false;
      final meu = perfilCadastroApoiador?.trim();
      if (meu == null || meu.isEmpty) return false;
      return meu.toLowerCase() == alvo.toLowerCase();
    case 'privada_assessores':
    default:
      return false;
  }
}

/// Critério alinhado a `mensagens_votante_read` (Supabase).
bool mensagemVisivelParaVotante(Mensagem m, List<Votante> vtsDoPerfil) {
  switch (m.escopo) {
    case 'global':
    case 'polo':
    case 'performance':
    case 'reuniao':
      return true;
    case 'cidade':
      if (m.municipiosIds.isEmpty) return false;
      for (final v in vtsDoPerfil) {
        final mid = v.municipioId;
        if (mid != null && mid.isNotEmpty && m.municipiosIds.contains(mid)) {
          return true;
        }
      }
      return false;
    case 'privada_apoiadores':
    case 'privada_assessores':
    case 'apoiador_classificacao':
    default:
      return false;
  }
}

final mensagensCountProvider = FutureProvider<int>((ref) async {
  final l = await ref.watch(mensagensVisiveisParaUsuarioProvider.future);
  return l.length;
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
      final rAp = await supabase
          .from('apoiadores')
          .select('profile_id, excluido_em')
          .not('profile_id', 'is', null);
      final apRows = (rAp as List).where((e) => e is Map && e['excluido_em'] == null).toList();
      final rAs = await supabase
          .from('assessores')
          .select('profile_id')
          .eq('ativo', true)
          .not('profile_id', 'is', null);
      final set = <String>{}
        ..addAll(_uniqProfileIds(apRows, 'profile_id'))
        ..addAll(_uniqProfileIds(rAs as List, 'profile_id'));
      return set.toList();
    case 'apoiador_classificacao':
      final raw = p.classificacaoApoiador?.trim();
      if (raw == null || raw.isEmpty) return [];
      final lower = raw.toLowerCase();
      final rAp = await supabase
          .from('apoiadores')
          .select('profile_id, perfil, excluido_em')
          .not('profile_id', 'is', null);
      final set = <String>{};
      for (final e in rAp as List) {
        if (e is! Map) continue;
        if (e['excluido_em'] != null) continue;
        final perfil = (e['perfil'] as String?)?.trim();
        if (perfil == null || perfil.isEmpty) continue;
        if (perfil.toLowerCase() != lower) continue;
        final id = e['profile_id']?.toString();
        if (id != null && id.isNotEmpty) set.add(id);
      }
      return set.toList();
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
      linkUrl: m.linkUrl,
      escopo: m.escopo,
      poloId: m.poloId,
      municipiosIds: m.municipiosIds,
      classificacaoApoiador: m.classificacaoApoiador,
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
    this.linkUrl,
    this.escopo = 'global',
    this.poloId,
    this.municipiosIds = const [],
    this.classificacaoApoiador,
    this.imagemJpegOpcional,
    this.enviarPush = false,
  });

  final String titulo;
  final String? corpo;
  final String? linkUrl;
  final String escopo;
  final String? poloId;
  final List<String> municipiosIds;
  /// Obrigatório quando [escopo] == `apoiador_classificacao` (texto = apoiadores.perfil).
  final String? classificacaoApoiador;
  /// JPEG já comprimido no cliente antes do upload ao Storage (`mensagens` bucket).
  final Uint8List? imagemJpegOpcional;
  final bool enviarPush;
}

final criarMensagemProvider = Provider<Future<Mensagem> Function(NovaMensagemParams)>((ref) {
  return (NovaMensagemParams p) async {
    final userId = ref.read(currentUserProvider)?.id;
    final linkNorm = Mensagem.normalizarLinkOpcional(p.linkUrl);

    final row = {
      'titulo': p.titulo.trim(),
      if (p.corpo != null && p.corpo!.trim().isNotEmpty) 'corpo': p.corpo!.trim(),
      if (linkNorm != null) 'link_url': linkNorm,
      'escopo': p.escopo,
      if (p.poloId != null) 'polo_id': p.poloId,
      if (p.municipiosIds.isNotEmpty) 'municipios_ids': p.municipiosIds,
      if (p.escopo == 'apoiador_classificacao' &&
          p.classificacaoApoiador != null &&
          p.classificacaoApoiador!.trim().isNotEmpty)
        'classificacao_apoiador': p.classificacaoApoiador!.trim(),
      'criado_por': userId,
    };

    final res = await supabase.from('mensagens').insert(row).select().single();
    var mensagem = Mensagem.fromJson(res);

    final jpeg = p.imagemJpegOpcional;
    if (jpeg != null && jpeg.isNotEmpty) {
      final uid = userId ?? '';
      if (uid.isEmpty) {
        await supabase.from('mensagens').delete().eq('id', mensagem.id);
        throw Exception('Sessão inválida para enviar imagem.');
      }
      final storagePath = '$uid/${mensagem.id}.jpg';
      try {
        await supabase.storage.from('mensagens').uploadBinary(
          storagePath,
          jpeg,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );
      } catch (e) {
        await supabase.from('mensagens').delete().eq('id', mensagem.id);
        throw Exception('Falha ao enviar a imagem da mensagem. $e');
      }
      final publicUrl = supabase.storage.from('mensagens').getPublicUrl(storagePath);
      final upd = await supabase
          .from('mensagens')
          .update({'imagem_url': publicUrl})
          .eq('id', mensagem.id)
          .select()
          .single();
      mensagem = Mensagem.fromJson(upd);
    }

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
        'body': Mensagem.textoParaNotificacao(
          corpo: mensagem.corpo,
          linkUrl: mensagem.linkUrl,
          imagemUrl: mensagem.imagemUrl,
        ),
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
      'body': Mensagem.textoParaNotificacao(
        corpo: m.corpo,
        linkUrl: m.linkUrl,
        imagemUrl: m.imagemUrl,
      ),
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
