import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/municipio.dart';
import '../../../models/votante.dart';
import '../../../core/supabase/municipios_seed.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../apoiadores/providers/apoiadores_provider.dart'
    show apoiadoresListProvider, meuApoiadorIdProvider;
import '../../mapa/providers/benfeitorias_agg_provider.dart';
import '../../assessores/providers/assessores_provider.dart'
    show assessoresListProvider, meuAssessorIdProvider;

final votantesListProvider = FutureProvider<List<Votante>>((ref) async {
  final profile = await ref.watch(profileProvider.future);
  if (profile == null) return [];

  if (profile.role == 'apoiador') {
    return ref.watch(meuApoiadorIdProvider).when(
          data: (apoiadorId) async {
            if (apoiadorId == null) return [];
            final res = await supabase
                .from('votantes')
                .select('*, municipios(nome)')
                .eq('apoiador_id', apoiadorId)
                .order('nome');
            return (res as List).map((e) => Votante.fromJson(e as Map<String, dynamic>)).toList();
          },
          loading: () async => [],
          error: (_, __) async => [],
        );
  }

  final res = await supabase.from('votantes').select('*, municipios(nome)').order('nome');
  return (res as List).map((e) => Votante.fromJson(e as Map<String, dynamic>)).toList();
});

/// Municípios MT — tenta seed automático client-side se a tabela estiver vazia.
final municipiosMTListProvider = FutureProvider<List<Municipio>>((ref) async {
  await ensureMunicipiosMtSeeded(supabase);
  final res = await supabase.from('municipios').select().order('nome');
  return (res as List).map((e) => Municipio.fromJson(e as Map<String, dynamic>)).toList();
});

/// Força re-leitura da tabela [municipios] (evita cache após seed).
Future<List<Municipio>> refreshMunicipiosMTList(WidgetRef ref) async {
  ref.invalidate(municipiosMTListProvider);
  return ref.read(municipiosMTListProvider.future);
}

class NovoVotanteParams {
  NovoVotanteParams({
    required this.nome,
    this.telefone,
    this.email,
    this.municipioId,
    required this.cidadeNome,
    this.abrangencia = 'Individual',
    this.qtdVotosFamilia = 1,
    this.apoiadorId,
    this.cep,
    this.logradouro,
    this.numero,
    this.complemento,
    this.votosPrometidosUltimaEleicao,
  });
  final String nome;
  final String? telefone;
  final String? email;
  final String? municipioId;
  final String cidadeNome;
  final String abrangencia;
  final int qtdVotosFamilia;
  final String? apoiadorId;
  final String? cep;
  final String? logradouro;
  final String? numero;
  final String? complemento;
  final int? votosPrometidosUltimaEleicao;
}

final criarVotanteProvider = Provider<Future<void> Function(NovoVotanteParams)>((ref) {
  final client = supabase;
  return (NovoVotanteParams params) async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) throw Exception('Faça login para cadastrar votantes.');

    final profile = await ref.read(profileProvider.future);
    final role = profile?.role;

    String? assessorId;
    String? apoiadorId = params.apoiadorId;

    if (role == 'apoiador') {
      final aid = await ref.read(meuApoiadorIdProvider.future);
      if (aid == null) {
        throw Exception(
          'Sua conta ainda não está vinculada ao cadastro de apoiador. Peça um convite por e-mail ao candidato ou assessor.',
        );
      }
      final row = await client.from('apoiadores').select('assessor_id').eq('id', aid).maybeSingle();
      assessorId = row?['assessor_id'] as String?;
      apoiadorId = aid;
      if (assessorId == null || assessorId.isEmpty) {
        throw Exception('Não foi possível identificar o assessor da campanha.');
      }
    } else {
      assessorId = await ref.read(meuAssessorIdProvider.future);
      if (assessorId == null) {
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
          throw Exception(
            'Ative o acesso de assessor/candidato em Assessores antes de cadastrar votantes.',
          );
        }
      }
    }

    final insert = <String, dynamic>{
      'assessor_id': assessorId,
      'nome': params.nome.trim(),
      'telefone': params.telefone?.trim().isEmpty == true ? null : params.telefone?.trim(),
      'email': params.email == null || params.email!.trim().isEmpty
          ? null
          : params.email!.trim().toLowerCase(),
      'municipio_id': params.municipioId,
      'cidade_nome': params.cidadeNome.trim().isEmpty ? null : params.cidadeNome.trim(),
      'abrangencia': params.abrangencia,
      'qtd_votos_familia': params.qtdVotosFamilia < 1 ? 1 : params.qtdVotosFamilia,
      if (apoiadorId != null && apoiadorId.isNotEmpty) 'apoiador_id': apoiadorId,
      'cep': params.cep?.trim().isEmpty == true ? null : params.cep?.trim(),
      'logradouro': params.logradouro?.trim().isEmpty == true ? null : params.logradouro?.trim(),
      'numero': params.numero?.trim().isEmpty == true ? null : params.numero?.trim(),
      'complemento': params.complemento?.trim().isEmpty == true ? null : params.complemento?.trim(),
      if (params.votosPrometidosUltimaEleicao != null)
        'votos_prometidos_ultima_eleicao': params.votosPrometidosUltimaEleicao,
    };

    await client.from('votantes').insert(insert);
    ref.invalidate(votantesListProvider);
  };
});

class AtualizarVotanteParams {
  AtualizarVotanteParams({
    this.nome,
    this.telefone,
    this.email,
    this.municipioId,
    this.cidadeNome,
    this.abrangencia,
    this.qtdVotosFamilia,
    this.cep,
    this.logradouro,
    this.numero,
    this.complemento,
    this.votosPrometidosUltimaEleicao,
    this.atualizarLegado = false,
  });
  final String? nome;
  final String? telefone;
  final String? email;
  final String? municipioId;
  final String? cidadeNome;
  final String? abrangencia;
  final int? qtdVotosFamilia;
  final String? cep;
  final String? logradouro;
  final String? numero;
  final String? complemento;
  final int? votosPrometidosUltimaEleicao;
  final bool atualizarLegado;
}

final atualizarVotanteProvider = Provider<Future<void> Function(String id, AtualizarVotanteParams)>((ref) {
  final client = supabase;
  return (String id, AtualizarVotanteParams p) async {
    final row = <String, dynamic>{};
    if (p.nome != null) row['nome'] = p.nome!.trim();
    if (p.telefone != null) row['telefone'] = p.telefone!.trim().isEmpty ? null : p.telefone!.trim();
    if (p.email != null) row['email'] = p.email!.trim().isEmpty ? null : p.email!.trim().toLowerCase();
    if (p.municipioId != null) row['municipio_id'] = p.municipioId!.trim().isEmpty ? null : p.municipioId;
    if (p.cidadeNome != null) row['cidade_nome'] = p.cidadeNome!.trim().isEmpty ? null : p.cidadeNome!.trim();
    if (p.abrangencia != null) row['abrangencia'] = p.abrangencia;
    if (p.qtdVotosFamilia != null) row['qtd_votos_familia'] = p.qtdVotosFamilia! < 1 ? 1 : p.qtdVotosFamilia!;
    if (p.cep != null) row['cep'] = p.cep!.trim().isEmpty ? null : p.cep!.trim();
    if (p.logradouro != null) row['logradouro'] = p.logradouro!.trim().isEmpty ? null : p.logradouro!.trim();
    if (p.numero != null) row['numero'] = p.numero!.trim().isEmpty ? null : p.numero!.trim();
    if (p.complemento != null) row['complemento'] = p.complemento!.trim().isEmpty ? null : p.complemento!.trim();
    if (p.atualizarLegado) row['votos_prometidos_ultima_eleicao'] = p.votosPrometidosUltimaEleicao;
    if (row.isEmpty) return;
    await client.from('votantes').update(row).eq('id', id);
    ref.invalidate(votantesListProvider);
  };
});

final removerVotanteProvider = Provider<Future<void> Function(String id)>((ref) {
  final client = supabase;
  return (String id) async {
    await client.from('votantes').delete().eq('id', id);
    ref.invalidate(votantesListProvider);
  };
});

/// Promove votante a apoiador (RPC). Retorna o id do novo apoiador.
final promoverVotanteParaApoiadorProvider = Provider<Future<String> Function(String votanteId)>((ref) {
  return (String votanteId) async {
    final res = await supabase.rpc(
      'promover_votante_para_apoiador',
      params: {'p_votante_id': votanteId},
    );
    ref.invalidate(votantesListProvider);
    ref.invalidate(apoiadoresListProvider);
    ref.invalidate(benfeitoriasAggPorMunicipioProvider);
    final id = res?.toString().trim();
    if (id == null || id.isEmpty) {
      throw Exception('Não foi possível promover o votante.');
    }
    return id;
  };
});
