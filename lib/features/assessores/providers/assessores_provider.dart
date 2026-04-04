import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/assessor.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../core/config/env_config.dart';
import '../../../core/router/profile_role_cache.dart';
import '../../auth/providers/auth_provider.dart';

/// ID do assessor vinculado ao usuário logado (`profile_id` = usuário atual).
final meuAssessorIdProvider = FutureProvider<String?>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return null;
  final res = await supabase.from('assessores').select('id').eq('profile_id', userId).maybeSingle();
  return res?['id'] as String?;
});

/// Extrai mensagem de erro amigável de Exception (incluindo FunctionException e erros PostgREST).
String messageFromException(Object e) {
  if (e is FunctionException) {
    final d = e.details;
    if (d is Map && d.containsKey('error')) {
      final msg = d['error'];
      if (msg is String) return msg;
    }
    if (d != null) return d.toString();
  }
  // PostgREST (RPC/tabela): função ausente, RLS, coluna inexistente, etc.
  try {
    final dynamic x = e;
    final m = x.message;
    if (m is String && m.trim().isNotEmpty) return m.trim();
    final c = x.code;
    final details = x.details;
    if (c != null && details != null) return '$c: $details';
  } catch (_) {}
  if (e is Exception) return e.toString().replaceFirst('Exception: ', '');
  return e.toString();
}

/// Converte retorno de [SupabaseClient.rpc] (jsonb) em mapa, mesmo quando vier
/// como `Map` genérico, JSON em string ou lista com um único objeto.
Map<String, dynamic> _coerceRpcJsonbResult(dynamic res) {
  if (res == null) {
    return {};
  }
  if (res is Map<String, dynamic>) {
    return res;
  }
  if (res is Map) {
    return Map<String, dynamic>.from(
      res.map((k, v) => MapEntry(k.toString(), v)),
    );
  }
  if (res is String) {
    final s = res.trim();
    if (s.isEmpty) {
      return {};
    }
    try {
      return _coerceRpcJsonbResult(jsonDecode(s));
    } catch (_) {
      return {'error': s};
    }
  }
  if (res is List && res.isNotEmpty) {
    return _coerceRpcJsonbResult(res.first);
  }
  return {'error': 'Resposta inválida do servidor (${res.runtimeType}).'};
}

bool _rpcOkFlag(dynamic v) =>
    v == true || v == 1 || v?.toString().toLowerCase() == 'true';

/// Garante [profiles] com `id` = usuário atual (RLS: linha própria). Cobre falha
/// do trigger `handle_new_user` e ambientes sem migração mais recente da RPC.
Future<void> _ensureMeuProfileRowNoCliente(User user) async {
  final email = user.email ?? '';
  final metaName = user.userMetadata?['full_name']?.toString().trim();
  final fullName = (metaName != null && metaName.isNotEmpty)
      ? metaName
      : (email.contains('@') ? email.split('@').first : 'Usuário');

  try {
    await supabase.from('profiles').upsert(
      {
        'id': user.id,
        if (email.isNotEmpty) 'email': email,
        'full_name': fullName,
        'ativo': true,
      },
      onConflict: 'id',
    );
  } on PostgrestException catch (e) {
    throw Exception(messageFromException(e));
  }
}

/// Registro completo do assessor logado (endereço, etc.).
final meuAssessorRegistroProvider = FutureProvider<Assessor?>((ref) async {
  final id = await ref.watch(meuAssessorIdProvider.future);
  if (id == null) return null;
  final res = await supabase.from('assessores').select().eq('id', id).maybeSingle();
  if (res == null) return null;
  return Assessor.fromJson(Map<String, dynamic>.from(res));
});

class AtualizarMeuAssessorEnderecoParams {
  AtualizarMeuAssessorEnderecoParams({
    this.cep,
    this.logradouro,
    this.numero,
    this.complemento,
  });
  final String? cep;
  final String? logradouro;
  final String? numero;
  final String? complemento;
}

final atualizarMeuAssessorEnderecoProvider = Provider<Future<void> Function(AtualizarMeuAssessorEnderecoParams)>((ref) {
  final client = supabase;
  return (AtualizarMeuAssessorEnderecoParams p) async {
    final id = await ref.read(meuAssessorIdProvider.future);
    if (id == null) throw Exception('Registro de assessor não encontrado.');
    final row = <String, dynamic>{
      'cep': p.cep?.trim().isEmpty == true ? null : p.cep?.trim(),
      'logradouro': p.logradouro?.trim().isEmpty == true ? null : p.logradouro?.trim(),
      'numero': p.numero?.trim().isEmpty == true ? null : p.numero?.trim(),
      'complemento': p.complemento?.trim().isEmpty == true ? null : p.complemento?.trim(),
    };
    final res = await client.from('assessores').update(row).eq('id', id).select('id').maybeSingle();
    if (res == null) {
      throw Exception('Não foi possível salvar o endereço. Confira permissões ou tente de novo.');
    }
    ref.invalidate(assessoresListProvider);
    ref.invalidate(meuAssessorRegistroProvider);
  };
});

final assessoresListProvider = FutureProvider<List<Assessor>>((ref) async {
  final profile = await ref.watch(profileProvider.future);
  final res = await supabase.from('assessores').select().order('nome');
  final list = (res as List).map((e) => Assessor.fromJson(e as Map<String, dynamic>)).toList();
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId != null && profile?.role == 'candidato') {
    return list.where((a) => a.profileId != userId).toList();
  }
  return list;
});

/// Convidar novo assessor (apenas candidato). A pessoa recebe convite por e-mail para criar senha e acessar o sistema.
/// Retorna [linkCopia] quando o servidor gera um link alternativo (enviar por WhatsApp se o e-mail não chegar).
Future<String?> convidarAssessor({
  required String nome,
  required String email,
  String? telefone,
  String? municipioId,
}) async {
  // Garantir sessão válida (evita 401 Invalid JWT por token expirado)
  await supabase.auth.refreshSession();

  final body = <String, dynamic>{
    'nome': nome.trim(),
    'email': email.trim().toLowerCase(),
    if (telefone != null && telefone.isNotEmpty) 'telefone': telefone.trim(),
    if (municipioId != null && municipioId.isNotEmpty) 'municipio_id': municipioId,
  };
  // Sempre usar URL do app em produção no convite (evita link localhost no e-mail)
  body['redirect_to'] = EnvConfig.appUrl;
  final res = await supabase.functions.invoke('convidar-assessor', body: body);
  if (res.status == 401) {
    throw Exception(
      'Sessão expirada. Faça logout, entre novamente e tente enviar o convite.',
    );
  }
  if (res.status != 200) {
    final msg = (res.data is Map && (res.data as Map).containsKey('error'))
        ? (res.data as Map)['error'] as String?
        : 'Erro ao convidar assessor';
    throw Exception(msg ?? 'Erro ao convidar assessor');
  }
  final data = res.data;
  if (data is Map && data.containsKey('error')) {
    throw Exception(data['error'] as String? ?? 'Erro ao convidar assessor');
  }
  if (data is Map && data['link_copia'] is String) {
    final s = (data['link_copia'] as String).trim();
    if (s.isNotEmpty) return s;
  }
  return null;
}

/// Reenviar convite por e-mail para um assessor já cadastrado (apenas candidato).
/// Retorna [linkCopia] quando disponível (enviar por WhatsApp se o e-mail não chegar).
Future<String?> reenviarConviteAssessor(Assessor assessor) async {
  await supabase.auth.refreshSession();
  try {
    final body = <String, dynamic>{
      'assessor_id': assessor.id,
      'redirect_to': EnvConfig.appUrl,
    };
    final res = await supabase.functions.invoke('reenviar-convite-assessor', body: body);
    if (res.status == 401) {
      throw Exception('Sessão expirada. Faça logout e entre novamente.');
    }
    if (res.status != 200) {
      final msg = (res.data is Map && (res.data as Map).containsKey('error'))
          ? (res.data as Map)['error'] as String?
          : 'Erro ao reenviar convite';
      throw Exception(msg ?? 'Erro ao reenviar convite');
    }
    final data = res.data;
    if (data is Map && data.containsKey('error')) {
      throw Exception(data['error'] as String? ?? 'Erro ao reenviar convite');
    }
    if (data is Map && data['link_copia'] is String) {
      final s = (data['link_copia'] as String).trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  } on FunctionException catch (e) {
    final msg = messageFromException(e);
    throw Exception(msg.isNotEmpty ? msg : 'Erro ao reenviar convite');
  }
}

/// Remover assessor (apenas candidato). Remove o registro e revoga o acesso.
Future<void> removerAssessor(String assessorId) async {
  await supabase.auth.refreshSession();
  await supabase.from('assessores').delete().eq('id', assessorId);
}

/// Desativar ou reativar assessor convidado (apenas candidato). Atualiza `assessores.ativo` e `profiles.ativo`.
Future<void> setAssessorAtivo({required String assessorId, required bool ativo}) async {
  await supabase.auth.refreshSession();
  try {
    await supabase.rpc(
      'candidato_set_assessor_ativo',
      params: {
        'p_assessor_id': assessorId,
        'p_ativo': ativo,
      },
    );
  } on FunctionException catch (e) {
    throw Exception(messageFromException(e));
  }
}

/// Promover o usuário atual a Candidato (Nível 1) se ainda não existir candidato no sistema.
/// Usa RPC no Postgres (migração `promover_candidato_se_vazio`); não depende da Edge Function deployada.
Future<void> promoverACandidato() async {
  await supabase.auth.refreshSession();
  final user = supabase.auth.currentUser;
  if (user == null) {
    throw Exception('Sessão inválida. Faça login novamente.');
  }

  await _ensureMeuProfileRowNoCliente(user);

  dynamic raw;
  try {
    raw = await supabase.rpc('promover_candidato_se_vazio');
  } on PostgrestException catch (e) {
    throw Exception(messageFromException(e));
  }

  final map = _coerceRpcJsonbResult(raw);
  final err = map['error'];
  if (err != null) {
    throw Exception(err is String ? err : err.toString());
  }
  if (!_rpcOkFlag(map['ok'])) {
    final m = map['message']?.toString() ?? '';
    if (m.contains('Acesso Candidato ativado')) {
      // Resposta legada sem campo `ok`
    } else {
      throw Exception(
        m.isNotEmpty
            ? m
            : 'O servidor não confirmou a ativação. Rode as migrações Supabase mais recentes e tente de novo.',
      );
    }
  }
  clearProfileRoleCache();
}
