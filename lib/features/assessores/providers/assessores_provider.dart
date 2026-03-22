import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/assessor.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../core/config/env_config.dart';
import '../../auth/providers/auth_provider.dart';

/// Extrai mensagem de erro amigável de Exception (incluindo FunctionException).
String messageFromException(Object e) {
  if (e is FunctionException) {
    final d = e.details;
    if (d is Map && d.containsKey('error')) {
      final msg = d['error'];
      if (msg is String) return msg;
    }
    if (d != null) return d.toString();
  }
  if (e is Exception) return e.toString().replaceFirst('Exception: ', '');
  return e.toString();
}

final assessoresListProvider = FutureProvider<List<Assessor>>((ref) async {
  final res = await supabase.from('assessores').select().order('nome');
  final list = (res as List).map((e) => Assessor.fromJson(e as Map<String, dynamic>)).toList();
  final userId = ref.watch(currentUserProvider)?.id;
  final profile = await ref.watch(profileProvider.future);
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

/// Promover o usuário atual a Candidato (Nível 1) se ainda não existir candidato no sistema.
Future<void> promoverACandidato() async {
  final res = await supabase.functions.invoke('promover-candidato');
  if (res.status != 200) {
    final msg = (res.data is Map && (res.data as Map).containsKey('error'))
        ? (res.data as Map)['error'] as String?
        : 'Erro ao ativar acesso';
    throw Exception(msg ?? 'Erro ao ativar acesso');
  }
  if (res.data is Map && (res.data as Map).containsKey('error')) {
    throw Exception((res.data as Map)['error'] as String? ?? 'Erro ao ativar acesso');
  }
}
