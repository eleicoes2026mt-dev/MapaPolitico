import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/assessor.dart';
import '../../../core/supabase/supabase_provider.dart';

final assessoresListProvider = FutureProvider<List<Assessor>>((ref) async {
  final res = await supabase.from('assessores').select().order('nome');
  return (res as List).map((e) => Assessor.fromJson(e as Map<String, dynamic>)).toList();
});

/// Convidar novo assessor (apenas candidato). A pessoa recebe convite por e-mail para criar senha e acessar o sistema.
Future<void> convidarAssessor({
  required String nome,
  required String email,
  String? telefone,
  String? municipioId,
}) async {
  // Garantir sessão válida (evita 401 Invalid JWT por token expirado)
  await supabase.auth.refreshSession();

  final res = await supabase.functions.invoke(
    'convidar-assessor',
    body: {
      'nome': nome.trim(),
      'email': email.trim().toLowerCase(),
      if (telefone != null && telefone.isNotEmpty) 'telefone': telefone.trim(),
      if (municipioId != null && municipioId.isNotEmpty) 'municipio_id': municipioId,
    },
  );
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
