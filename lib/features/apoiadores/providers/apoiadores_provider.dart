import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/apoiador.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../core/config/env_config.dart';
import '../../auth/providers/auth_provider.dart';
import '../../assessores/providers/assessores_provider.dart'
    show promoverACandidato, messageFromException, assessoresListProvider;
import '../../benfeitorias/providers/benfeitorias_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

/// Linha em `apoiadores` vinculada ao usuário com role `apoiador` (convite por e-mail).
final meuApoiadorIdProvider = FutureProvider<String?>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return null;
  final res = await supabase.from('apoiadores').select('id').eq('profile_id', userId).maybeSingle();
  return res?['id'] as String?;
});

/// Item de benfeitoria para cadastro junto com o apoiador.
class NovaBenfeitoriaItem {
  const NovaBenfeitoriaItem({
    required this.titulo,
    required this.tipo,
    required this.valor,
    this.dataRealizacao,
    this.descricao,
  });
  final String titulo;
  final String tipo;
  final double valor;
  final DateTime? dataRealizacao;
  final String? descricao;
}

/// Parâmetros para criar um novo apoiador.
class NovoApoiadorParams {
  NovoApoiadorParams({
    required this.nome,
    required this.cidadeNome,
    this.tipo = 'PF',
    this.perfil,
    this.telefone,
    this.email,
    this.estimativaVotos = 0,
    this.municipioId,
    this.dataNascimento,
    this.votosSozinho = true,
    this.qtdVotosFamilia = 0,
    this.cnpj,
    this.razaoSocial,
    this.nomeFantasia,
    this.situacaoCnpj,
    this.endereco,
    this.contatoResponsavel,
    this.emailResponsavel,
    this.votosPf = 0,
    this.votosFamilia = 0,
    this.votosFuncionarios = 0,
    this.votosPrometidosUltimaEleicao,
    this.benfeitorias = const [],
  });
  final String nome;
  final String cidadeNome;
  final String tipo;
  final String? perfil;
  final String? telefone;
  final String? email;
  final int estimativaVotos;
  final String? municipioId;
  final DateTime? dataNascimento;
  final bool votosSozinho;
  final int qtdVotosFamilia;
  final String? cnpj;
  final String? razaoSocial;
  final String? nomeFantasia;
  final String? situacaoCnpj;
  final String? endereco;
  final String? contatoResponsavel;
  final String? emailResponsavel;
  final int votosPf;
  final int votosFamilia;
  final int votosFuncionarios;
  final int? votosPrometidosUltimaEleicao;
  final List<NovaBenfeitoriaItem> benfeitorias;
}

final criarApoiadorProvider = Provider<Future<void> Function(NovoApoiadorParams)>((ref) {
  final client = supabase;
  return (NovoApoiadorParams params) async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) throw Exception('Faça login para cadastrar apoiadores.');

    var assessorId = await ref.read(meuAssessorIdProvider.future);
    if (assessorId == null) {
      final profile = await ref.read(profileProvider.future);
      if (profile?.role == 'candidato') {
        try {
          await client.from('assessores').insert({
            'profile_id': userId,
            'nome': profile!.fullName?.trim().isNotEmpty == true
                ? profile.fullName!.trim()
                : (profile.email ?? 'Candidato'),
          });
          ref.invalidate(meuAssessorIdProvider);
          ref.invalidate(assessoresListProvider);
          assessorId = await ref.read(meuAssessorIdProvider.future);
        } catch (_) {}
      }
      if (assessorId == null) {
        try {
          await promoverACandidato();
          ref.invalidate(meuAssessorIdProvider);
          ref.invalidate(assessoresListProvider);
          assessorId = await ref.read(meuAssessorIdProvider.future);
        } catch (_) {}
      }
      if (assessorId == null) {
        throw Exception(
          'Não foi possível ativar seu acesso. Vá em Assessores e clique em "Sou o Candidato – Ativar acesso", depois tente cadastrar o apoiador de novo.',
        );
      }
    }

    final row = <String, dynamic>{
      'assessor_id': assessorId,
      'nome': params.nome.trim(),
      'tipo': params.tipo,
      'perfil': params.perfil?.trim().isEmpty == true ? null : params.perfil?.trim(),
      'telefone': params.telefone?.trim().isEmpty == true ? null : params.telefone?.trim(),
      'email': params.email?.trim().isEmpty == true ? null : params.email?.trim(),
      'estimativa_votos': params.estimativaVotos,
      'cidades_atuacao': [],
      'ativo': true,
      'cidade_nome': params.cidadeNome.trim().isEmpty ? null : params.cidadeNome.trim(),
      'municipio_id': params.municipioId,
      'data_nascimento': params.dataNascimento?.toIso8601String().split('T').first,
      'votos_sozinho': params.votosSozinho,
      'qtd_votos_familia': params.qtdVotosFamilia,
      'cnpj': params.cnpj?.trim().isEmpty == true ? null : params.cnpj?.replaceAll(RegExp(r'[^\d]'), ''),
      'razao_social': params.razaoSocial?.trim().isEmpty == true ? null : params.razaoSocial?.trim(),
      'nome_fantasia': params.nomeFantasia?.trim().isEmpty == true ? null : params.nomeFantasia?.trim(),
      'situacao_cnpj': params.situacaoCnpj?.trim().isEmpty == true ? null : params.situacaoCnpj?.trim(),
      'endereco': params.endereco?.trim().isEmpty == true ? null : params.endereco?.trim(),
      'contato_responsavel': params.contatoResponsavel?.trim().isEmpty == true ? null : params.contatoResponsavel?.trim(),
      'email_responsavel': params.emailResponsavel?.trim().isEmpty == true ? null : params.emailResponsavel?.trim(),
      'votos_pf': params.votosPf,
      'votos_familia': params.votosFamilia,
      'votos_funcionarios': params.votosFuncionarios,
      'votos_prometidos_ultima_eleicao': params.votosPrometidosUltimaEleicao,
    };

    final res = await client.from('apoiadores').insert(row).select('id').maybeSingle();
    final apoiadorId = res?['id'] as String?;
    if (apoiadorId == null) throw Exception('Falha ao criar apoiador.');

    for (final b in params.benfeitorias) {
      await client.from('benfeitorias').insert({
        'apoiador_id': apoiadorId,
        'titulo': b.titulo.trim(),
        'descricao': b.descricao?.trim().isEmpty == true ? null : b.descricao?.trim(),
        'valor': b.valor,
        'data_realizacao': b.dataRealizacao?.toIso8601String().split('T').first,
        'tipo': b.tipo,
        'status': 'concluida',
      });
    }

    ref.invalidate(apoiadoresListProvider);
    ref.invalidate(benfeitoriasListProvider);
  };
});

/// Parâmetros opcionais para atualizar um apoiador (só candidato e assessores).
/// Para limpar o legado, use [atualizarLegado: true] e [votosPrometidosUltimaEleicao: null].
class AtualizarApoiadorParams {
  AtualizarApoiadorParams({
    this.nome,
    this.cidadeNome,
    this.telefone,
    this.email,
    this.estimativaVotos,
    this.votosPrometidosUltimaEleicao,
    this.atualizarLegado = false,
  });
  final String? nome;
  final String? cidadeNome;
  final String? telefone;
  final String? email;
  final int? estimativaVotos;
  final int? votosPrometidosUltimaEleicao;
  /// Se true, atualiza votos_prometidos_ultima_eleicao (inclusive para null).
  final bool atualizarLegado;
}

final atualizarApoiadorProvider = Provider<Future<void> Function(String apoiadorId, AtualizarApoiadorParams params)>((ref) {
  final client = supabase;
  return (String apoiadorId, AtualizarApoiadorParams params) async {
    final row = <String, dynamic>{};
    if (params.nome != null) row['nome'] = params.nome!.trim();
    if (params.cidadeNome != null) row['cidade_nome'] = params.cidadeNome!.trim().isEmpty ? null : params.cidadeNome!.trim();
    if (params.telefone != null) row['telefone'] = params.telefone!.trim().isEmpty ? null : params.telefone!.trim();
    if (params.email != null) row['email'] = params.email!.trim().isEmpty ? null : params.email!.trim();
    if (params.estimativaVotos != null) row['estimativa_votos'] = params.estimativaVotos!;
    if (params.atualizarLegado) row['votos_prometidos_ultima_eleicao'] = params.votosPrometidosUltimaEleicao;
    if (row.isEmpty) return;
    await client.from('apoiadores').update(row).eq('id', apoiadorId);
    ref.invalidate(apoiadoresListProvider);
  };
});

/// Convidar apoiador por e-mail (cria usuário com role apoiador e preenche `apoiadores.profile_id`).
Future<String?> convidarApoiadorPorEmail({required String apoiadorId}) async {
  await supabase.auth.refreshSession();
  try {
    final body = <String, dynamic>{
      'apoiador_id': apoiadorId,
      'redirect_to': EnvConfig.appUrl,
    };
    final res = await supabase.functions.invoke('convidar-apoiador', body: body);
    if (res.status == 401) {
      throw Exception('Sessão expirada. Faça login novamente.');
    }
    if (res.status != 200) {
      final msg = (res.data is Map && (res.data as Map).containsKey('error'))
          ? (res.data as Map)['error'] as String?
          : 'Erro ao convidar apoiador';
      throw Exception(msg ?? 'Erro ao convidar apoiador');
    }
    final data = res.data;
    if (data is Map && data.containsKey('error')) {
      throw Exception(data['error'] as String? ?? 'Erro ao convidar apoiador');
    }
    if (data is Map && data['link_copia'] is String) {
      final s = (data['link_copia'] as String).trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  } on FunctionException catch (e) {
    throw Exception(messageFromException(e));
  }
}

/// Reenviar convite (apoiador ainda sem `profile_id` vinculado).
Future<String?> reenviarConviteApoiador({required String apoiadorId}) async {
  await supabase.auth.refreshSession();
  try {
    final body = <String, dynamic>{
      'apoiador_id': apoiadorId,
      'redirect_to': EnvConfig.appUrl,
    };
    final res = await supabase.functions.invoke('reenviar-convite-apoiador', body: body);
    if (res.status == 401) throw Exception('Sessão expirada.');
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
    throw Exception(messageFromException(e));
  }
}
