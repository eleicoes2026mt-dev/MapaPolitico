import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/apoiador.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../assessores/providers/assessores_provider.dart';

final apoiadoresListProvider = FutureProvider<List<Apoiador>>((ref) async {
  final res = await supabase.from('apoiadores').select().order('nome');
  return (res as List).map((e) => Apoiador.fromJson(e as Map<String, dynamic>)).toList();
});

/// ID do assessor vinculado ao usuário logado (profile_id = current user). Candidato precisa ter ativado acesso em Assessores.
final meuAssessorIdProvider = FutureProvider<String?>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return null;
  final res = await supabase.from('assessores').select('id').eq('profile_id', userId).maybeSingle();
  return res?['id'] as String?;
});

/// Parâmetros para criar um novo apoiador.
class NovoApoiadorParams {
  NovoApoiadorParams({
    required this.nome,
    this.tipo = 'PF',
    this.perfil,
    this.telefone,
    this.email,
    this.estimativaVotos = 0,
  });
  final String nome;
  final String tipo;
  final String? perfil;
  final String? telefone;
  final String? email;
  final int estimativaVotos;
}

final criarApoiadorProvider = Provider<Future<void> Function(NovoApoiadorParams)>((ref) {
  final client = supabase;
  return (NovoApoiadorParams params) async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) throw Exception('Faça login para cadastrar apoiadores.');

    var assessorId = await ref.read(meuAssessorIdProvider.future);
    if (assessorId == null) {
      try {
        await promoverACandidato();
        ref.invalidate(meuAssessorIdProvider);
        ref.invalidate(assessoresListProvider);
        assessorId = await ref.read(meuAssessorIdProvider.future);
      } catch (_) {}
      if (assessorId == null) {
        throw Exception(
          'Não foi possível ativar seu acesso. Vá em Assessores e clique em "Sou o Candidato – Ativar acesso", depois tente cadastrar o apoiador de novo.',
        );
      }
    }

    await client.from('apoiadores').insert({
      'assessor_id': assessorId,
      'nome': params.nome.trim(),
      'tipo': params.tipo,
      'perfil': params.perfil?.trim().isEmpty == true ? null : params.perfil?.trim(),
      'telefone': params.telefone?.trim().isEmpty == true ? null : params.telefone?.trim(),
      'email': params.email?.trim().isEmpty == true ? null : params.email?.trim(),
      'estimativa_votos': params.estimativaVotos,
      'cidades_atuacao': [],
      'ativo': true,
    });
    ref.invalidate(apoiadoresListProvider);
  };
});
