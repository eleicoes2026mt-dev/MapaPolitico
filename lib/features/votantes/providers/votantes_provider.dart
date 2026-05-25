import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/amigos_gilberto.dart';
import '../../../models/municipio.dart';
import '../../../models/profile.dart';
import '../../../models/votante.dart';
import '../../../core/supabase/municipios_seed.dart' show ensureMunicipiosMtSeeded, forceMunicipiosMtRecovery;
import '../../../core/supabase/supabase_provider.dart';
import '../../../core/router/profile_role_cache.dart';
import '../../auth/providers/auth_provider.dart';
import '../../apoiadores/providers/apoiadores_provider.dart'
    show apoiadoresListProvider, meuApoiadorIdProvider;
import '../../mapa/providers/benfeitorias_agg_provider.dart';
import '../../assessores/providers/assessores_provider.dart'
    show assessoresListProvider, meuAssessorIdProvider;

const _kVotantesSelect = '*, municipios(nome)';

/// Nome em [votantes.convite_por_nome]: quem fez o registo no painel (indicação e coluna «Apoiador»).
String? _nomeRegistradorParaConvite(Profile? profile) {
  if (profile == null) return null;
  final n = profile.fullName?.trim();
  if (n != null && n.isNotEmpty) return n;
  final e = profile.email?.trim();
  if (e != null && e.isNotEmpty && e.contains('@')) {
    final local = e.split('@').first.trim();
    if (local.isNotEmpty) return local;
  }
  return null;
}

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
        .order('nome', ascending: true);
    return (res as List).map((e) => Votante.fromJson(e as Map<String, dynamic>)).toList();
  }

  if (profile.role == 'apoiador') {
    return ref.watch(meuApoiadorIdProvider).when(
          data: (apoiadorId) async {
            if (apoiadorId == null) return [];
            final uid = profile.id;
            final res = profile.cadastroViaQr
                ? await supabase
                    .from('votantes')
                    .select(_kVotantesSelect)
                    .or('apoiador_id.eq.$apoiadorId,convite_por_profile_id.eq.$uid')
                    .order('nome', ascending: true)
                : await supabase
                    .from('votantes')
                    .select(_kVotantesSelect)
                    .eq('apoiador_id', apoiadorId)
                    .order('nome', ascending: true);
            return (res as List).map((e) => Votante.fromJson(e as Map<String, dynamic>)).toList();
          },
          loading: () async => [],
          error: (_, __) async => [],
        );
  }

  final res = await supabase
      .from('votantes')
      .select(_kVotantesSelect)
      .order('nome', ascending: true);
  return (res as List).map((e) => Votante.fromJson(e as Map<String, dynamic>)).toList();
});

/// Lista usada apenas por [IndicacoesRedeDashboardScreen].
///
/// Perfis `votante` estão restritos pela RLS a `profile_id = auth.uid()` nas leituras
/// normais; a sub-rede de indicações precisa também dos convidados (e níveis seguintes).
/// Chama RPC [app_votantes_subrede_indicacoes_votante_logado] quando o papel é votante.
final votantesIndicacaoRedeListProvider = FutureProvider<List<Votante>>((ref) async {
  final profile = await ref.watch(profileProvider.future);
  if (profile == null) return [];

  if (profile.role != 'votante') {
    return await ref.watch(votantesListProvider.future);
  }

  dynamic raw;
  try {
    raw = await supabase.rpc('app_votantes_subrede_indicacoes_votante_logado');
  } catch (_) {
    return await ref.watch(votantesListProvider.future);
  }

  if (raw is! List || raw.isEmpty) {
    return await ref.watch(votantesListProvider.future);
  }

  try {
    return raw
        .map((e) => Votante.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  } catch (_) {
    return await ref.watch(votantesListProvider.future);
  }
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
    this.linkInstagram,
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
  final String? linkInstagram;
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
      'link_instagram': params.linkInstagram?.trim().isEmpty == true ? null : params.linkInstagram?.trim(),
    };

    final nomeConvite = _nomeRegistradorParaConvite(profile);
    if (nomeConvite != null && nomeConvite.isNotEmpty) {
      insert['convite_por_profile_id'] = userId;
      insert['convite_por_nome'] = nomeConvite;
    }

    await client.from('votantes').insert(insert);
    ref.invalidate(votantesListProvider);
    ref.invalidate(votantesIndicacaoRedeListProvider);
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
    this.linkInstagram,
    this.atualizarLinkInstagram = false,
    this.convitePorNome,
    this.atualizarConviteIndicacao = false,
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
  final String? linkInstagram;
  /// Se true, grava [linkInstagram] (string vazia → null no banco).
  final bool atualizarLinkInstagram;
  /// Só pelo candidato: texto da coluna Indicação/Apoiador (lista); vazio ⇒ null na base.
  final String? convitePorNome;
  /// Quando true, grava [convite_por_nome] e define `convite_por_profile_id` a null (indicação manual).
  final bool atualizarConviteIndicacao;
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
    if (p.atualizarLinkInstagram) {
      row['link_instagram'] = p.linkInstagram?.trim().isEmpty == true ? null : p.linkInstagram?.trim();
    }
    if (p.atualizarConviteIndicacao) {
      final t = p.convitePorNome?.trim();
      row['convite_por_nome'] = (t == null || t.isEmpty) ? null : t;
      row['convite_por_profile_id'] = null;
    }
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
    ref.invalidate(votantesIndicacaoRedeListProvider);
  };
});

final removerVotanteProvider = Provider<Future<void> Function(String id)>((ref) {
  final client = supabase;
  return (String id) async {
    await client.from('votantes').delete().eq('id', id);
    ref.invalidate(votantesListProvider);
    ref.invalidate(votantesIndicacaoRedeListProvider);
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
    ref.invalidate(votantesIndicacaoRedeListProvider);
    ref.invalidate(apoiadoresListProvider);
    ref.invalidate(benfeitoriasAggPorMunicipioProvider);
    final id = res?.toString().trim();
    if (id == null || id.isEmpty) {
      throw Exception('Não foi possível promover o votante.');
    }
    return id;
  };
});

/// Promove votante a assessor na mesma campanha (RPC). Retorna [assessores.id].
/// Mantém vínculos de rede por UUID do perfil (convites por QR/link); só remove a linha em [votantes].
final promoverVotanteParaAssessorProvider = Provider<
    Future<String> Function(String votanteId, {String? promotedProfileId})>((ref) {
  return (String votanteId, {String? promotedProfileId}) async {
    final res = await supabase.rpc(
      'promover_votante_para_assessor',
      params: {'p_votante_id': votanteId},
    );
    ref.invalidate(votantesListProvider);
    ref.invalidate(votantesIndicacaoRedeListProvider);
    ref.invalidate(apoiadoresListProvider);
    ref.invalidate(assessoresListProvider);
    ref.invalidate(benfeitoriasAggPorMunicipioProvider);
    final pu = promotedProfileId?.trim();
    final me = ref.read(currentUserProvider)?.id;
    if (pu != null &&
        pu.isNotEmpty &&
        me != null &&
        pu == me) {
      clearProfileRoleCache();
      ref.invalidate(profileProvider);
    }
    final id = res?.toString().trim();
    if (id == null || id.isEmpty) {
      throw Exception('Não foi possível promover a assessor.');
    }
    return id;
  };
});
