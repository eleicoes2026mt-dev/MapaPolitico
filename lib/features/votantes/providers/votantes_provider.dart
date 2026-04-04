import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/amigos_gilberto.dart';
import '../../../models/municipio.dart';
import '../../../models/votante.dart';
import '../../../core/supabase/municipios_seed.dart' show ensureMunicipiosMtSeeded, forceMunicipiosMtRecovery;
import '../../../core/supabase/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../apoiadores/providers/apoiadores_provider.dart'
    show apoiadoresListProvider, meuApoiadorIdProvider;
import '../../mapa/providers/benfeitorias_agg_provider.dart';
import '../../assessores/providers/assessores_provider.dart'
    show assessoresListProvider, meuAssessorIdProvider;

const _kVotantesSelect = '*, municipios(nome)';

List<Municipio> _municipiosFromRpc(dynamic raw) {
  if (raw is! List) return [];
  return raw.map((e) {
    final m = e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map);
    return Municipio.fromJson(m);
  }).toList();
}

/// Tenta obter o catálogo via RPC (seed no servidor + linhas na resposta).
Future<List<Municipio>> _fetchMunicipiosCatalogoRpc() async {
  try {
    final raw = await supabase.rpc('municipios_catalogo_para_app');
    return _municipiosFromRpc(raw);
  } catch (_) {
    return [];
  }
}

final votantesListProvider = FutureProvider<List<Votante>>((ref) async {
  final profile = await ref.watch(profileProvider.future);
  if (profile == null) return [];

  if (profile.role == 'votante') {
    final uid = profile.id;
    final res = await supabase
        .from('votantes')
        .select(_kVotantesSelect)
        .eq('profile_id', uid)
        .order('nome');
    return (res as List).map((e) => Votante.fromJson(e as Map<String, dynamic>)).toList();
  }

  if (profile.role == 'apoiador') {
    return ref.watch(meuApoiadorIdProvider).when(
          data: (apoiadorId) async {
            if (apoiadorId == null) return [];
            final res = await supabase
                .from('votantes')
                .select(_kVotantesSelect)
                .eq('apoiador_id', apoiadorId)
                .order('nome');
            return (res as List).map((e) => Votante.fromJson(e as Map<String, dynamic>)).toList();
          },
          loading: () async => [],
          error: (_, __) async => [],
        );
  }

  final res = await supabase.from('votantes').select(_kVotantesSelect).order('nome');
  return (res as List).map((e) => Votante.fromJson(e as Map<String, dynamic>)).toList();
});

/// Municípios MT — tenta seed automático client-side se a tabela estiver vazia.
/// Se o SELECT vier vazio, usa RPC [municipios_catalogo_para_app] (seed no servidor + linhas na resposta).
/// Por último [forceMunicipiosMtRecovery] (upsert em lotes no cliente).
final municipiosMTListProvider = FutureProvider<List<Municipio>>((ref) async {
  await ensureMunicipiosMtSeeded(supabase);
  var res = await supabase.from('municipios').select().order('nome');
  var list = (res as List).map((e) => Municipio.fromJson(e as Map<String, dynamic>)).toList();
  if (list.isEmpty) {
    list = await _fetchMunicipiosCatalogoRpc();
  }
  if (list.isEmpty) {
    await forceMunicipiosMtRecovery(supabase);
    res = await supabase.from('municipios').select().order('nome');
    list = (res as List).map((e) => Municipio.fromJson(e as Map<String, dynamic>)).toList();
  }
  if (list.isEmpty) {
    list = await _fetchMunicipiosCatalogoRpc();
  }
  return list;
});

/// Força re-leitura da tabela [municipios] e nova tentativa de preenchimento em lotes.
Future<List<Municipio>> refreshMunicipiosMTList(WidgetRef ref) async {
  await _fetchMunicipiosCatalogoRpc();
  await forceMunicipiosMtRecovery(supabase);
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
    this.cadastroViaQr = false,
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
  /// Marca linha como cadastro público (QR / link Amigos do Gilberto).
  final bool cadastroViaQr;
}

final criarVotanteProvider = Provider<Future<void> Function(NovoVotanteParams)>((ref) {
  final client = supabase;
  return (NovoVotanteParams params) async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) throw Exception('Faça login para cadastrar $kAmigosGilbertoLabel.');

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
    } else if (role == 'votante') {
      final raw = await client.rpc('app_assessor_id_do_candidato');
      if (raw == null) {
        throw Exception(
          'Não foi possível localizar a campanha. O candidato precisa ter cadastro em Assessores ativo.',
        );
      }
      assessorId = raw is String ? raw : raw.toString();
      if (assessorId.isEmpty) {
        throw Exception('Campanha não configurada.');
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
            'Ative o acesso de assessor/candidato em Assessores antes de cadastrar $kAmigosGilbertoLabel.',
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
      if (role == 'votante') 'profile_id': userId,
      'cep': params.cep?.trim().isEmpty == true ? null : params.cep?.trim(),
      'logradouro': params.logradouro?.trim().isEmpty == true ? null : params.logradouro?.trim(),
      'numero': params.numero?.trim().isEmpty == true ? null : params.numero?.trim(),
      'complemento': params.complemento?.trim().isEmpty == true ? null : params.complemento?.trim(),
      if (params.votosPrometidosUltimaEleicao != null)
        'votos_prometidos_ultima_eleicao': params.votosPrometidosUltimaEleicao,
      // Só marca na linha quando o perfil veio do link/QR (evita confundir com cadastro pelo candidato).
      if (params.cadastroViaQr) 'cadastro_via_qr': true,
      if (role == 'candidato') 'cadastrado_pelo_candidato': true,
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
    final updated = await client.from('votantes').update(row).eq('id', id).select('id').maybeSingle();
    if (updated == null) {
      throw Exception(
        'Não foi possível salvar os dados (nenhuma linha atualizada). '
        'Se o cadastro foi por convite de apoiador, atualize o app e tente de novo; '
        'em último caso, peça ao candidato para ajustar no painel.',
      );
    }
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
