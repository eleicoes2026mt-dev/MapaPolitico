import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/apoiador.dart';
import '../../../models/municipio.dart';
import '../../../core/utils/municipio_resolver.dart';
import '../../../core/supabase/municipios_seed.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../core/config/env_config.dart';
import '../../auth/providers/auth_provider.dart';
import '../../assessores/providers/assessores_provider.dart'
    show promoverACandidato, messageFromException, assessoresListProvider, meuAssessorIdProvider;
import '../../benfeitorias/providers/benfeitorias_provider.dart';
import '../../mapa/providers/benfeitorias_agg_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final apoiadoresListProvider = FutureProvider<List<Apoiador>>((ref) async {
  // Não use select(role) com valueOrNull: em AsyncLoading o role vira null, o provider
  // reinicia em loop e a lista fica eternamente em loading na web.
  final profile = await ref.watch(profileProvider.future);
  // Apoiador não deve listar outros apoiadores (tela só para candidato/assessor).
  if (profile?.role == 'apoiador') return [];

  // Ocultar soft-deletes: RLS idealmente já não devolve linhas; filtro no cliente cobre DB/RLS antigos.
  final res = await supabase.from('apoiadores').select().order('nome');
  return (res as List)
      .map((e) => Apoiador.fromJson(e as Map<String, dynamic>))
      .where((a) => a.excluidoEm == null)
      .toList();
});

/// Linha em `apoiadores` vinculada ao usuário com role `apoiador` (convite por e-mail).
final meuApoiadorIdProvider = FutureProvider<String?>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return null;
  final res = await supabase.from('apoiadores').select('id').eq('profile_id', userId).maybeSingle();
  return res?['id'] as String?;
});

/// Cadastro completo do apoiador logado (para bandeira no mapa / perfil).
final meuApoiadorProvider = FutureProvider<Apoiador?>((ref) async {
  final id = await ref.watch(meuApoiadorIdProvider.future);
  if (id == null) return null;
  final res = await supabase.from('apoiadores').select().eq('id', id).maybeSingle();
  if (res == null) return null;
  return Apoiador.fromJson(Map<String, dynamic>.from(res));
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
    this.cep,
    this.logradouro,
    this.numero,
    this.complemento,
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
  final String? cep;
  final String? logradouro;
  final String? numero;
  final String? complemento;
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

    var municipioIdFinal = params.municipioId;
    if (municipioIdFinal == null || municipioIdFinal.trim().isEmpty) {
      await ensureMunicipiosMtSeeded(client);
      final resMun = await client.from('municipios').select();
      final listaMun = (resMun as List).map((e) => Municipio.fromJson(e as Map<String, dynamic>)).toList();
      municipioIdFinal = municipioIdParaNomeCidade(params.cidadeNome, listaMun);
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
      'municipio_id': municipioIdFinal,
      'data_nascimento': params.dataNascimento?.toIso8601String().split('T').first,
      'votos_sozinho': params.votosSozinho,
      'qtd_votos_familia': params.qtdVotosFamilia,
      'cnpj': params.cnpj?.trim().isEmpty == true ? null : params.cnpj?.replaceAll(RegExp(r'[^\d]'), ''),
      'razao_social': params.razaoSocial?.trim().isEmpty == true ? null : params.razaoSocial?.trim(),
      'nome_fantasia': params.nomeFantasia?.trim().isEmpty == true ? null : params.nomeFantasia?.trim(),
      'situacao_cnpj': params.situacaoCnpj?.trim().isEmpty == true ? null : params.situacaoCnpj?.trim(),
      'endereco': params.endereco?.trim().isEmpty == true ? null : params.endereco?.trim(),
      'cep': params.cep?.trim().isEmpty == true ? null : params.cep?.trim(),
      'logradouro': params.logradouro?.trim().isEmpty == true ? null : params.logradouro?.trim(),
      'numero': params.numero?.trim().isEmpty == true ? null : params.numero?.trim(),
      'complemento': params.complemento?.trim().isEmpty == true ? null : params.complemento?.trim(),
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
        'municipio_id': municipioIdFinal,
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
    ref.invalidate(benfeitoriasAggPorMunicipioProvider);
  };
});

/// Parâmetros opcionais para atualizar um apoiador (só candidato e assessores).
/// Para limpar o legado, use [atualizarLegado: true] e [votosPrometidosUltimaEleicao: null].
class AtualizarApoiadorParams {
  AtualizarApoiadorParams({
    this.nome,
    this.cidadeNome,
    this.municipioId,
    this.telefone,
    this.email,
    this.estimativaVotos,
    this.votosPrometidosUltimaEleicao,
    this.atualizarLegado = false,
    this.bandeiraIniciais,
    this.bandeiraCorPrimaria,
    this.bandeiraCorSecundaria,
    this.bandeiraSimbolo,
    this.bandeiraEmoji,
    this.atualizarBandeira = false,
    this.bandeiraVisualJson,
    this.cep,
    this.logradouro,
    this.numero,
    this.complemento,
    this.atualizarEndereco = false,
  });
  final String? nome;
  final String? cidadeNome;
  /// Quando preenchido, atualiza `municipio_id` (UUID da tabela `municipios`).
  final String? municipioId;
  final String? telefone;
  final String? email;
  final int? estimativaVotos;
  final int? votosPrometidosUltimaEleicao;
  /// Se true, atualiza votos_prometidos_ultima_eleicao (inclusive para null).
  final bool atualizarLegado;
  final String? bandeiraIniciais;
  final String? bandeiraCorPrimaria;
  final String? bandeiraCorSecundaria;
  final String? bandeiraSimbolo;
  final String? bandeiraEmoji;
  /// Se true, grava campos de bandeira (permite limpar com null nos opcionais).
  final bool atualizarBandeira;
  /// JSON do editor visual (`bandeira_visual`); quando preenchido, grava junto com os campos legados.
  final Map<String, dynamic>? bandeiraVisualJson;
  final String? cep;
  final String? logradouro;
  final String? numero;
  final String? complemento;
  /// Se true, grava CEP/logradouro/número/complemento (permite limpar com string vazia → null).
  final bool atualizarEndereco;
}

final atualizarApoiadorProvider = Provider<Future<void> Function(String apoiadorId, AtualizarApoiadorParams params)>((ref) {
  final client = supabase;
  return (String apoiadorId, AtualizarApoiadorParams params) async {
    final row = <String, dynamic>{};
    if (params.nome != null) row['nome'] = params.nome!.trim();
    if (params.cidadeNome != null) row['cidade_nome'] = params.cidadeNome!.trim().isEmpty ? null : params.cidadeNome!.trim();
    if (params.municipioId != null) {
      row['municipio_id'] = params.municipioId!.trim().isEmpty ? null : params.municipioId!.trim();
    }
    if (params.telefone != null) row['telefone'] = params.telefone!.trim().isEmpty ? null : params.telefone!.trim();
    if (params.email != null) row['email'] = params.email!.trim().isEmpty ? null : params.email!.trim();
    if (params.estimativaVotos != null) row['estimativa_votos'] = params.estimativaVotos!;
    if (params.atualizarLegado) row['votos_prometidos_ultima_eleicao'] = params.votosPrometidosUltimaEleicao;
    if (params.atualizarEndereco) {
      row['cep'] = params.cep?.trim().isEmpty == true ? null : params.cep?.trim();
      row['logradouro'] = params.logradouro?.trim().isEmpty == true ? null : params.logradouro?.trim();
      row['numero'] = params.numero?.trim().isEmpty == true ? null : params.numero?.trim();
      row['complemento'] = params.complemento?.trim().isEmpty == true ? null : params.complemento?.trim();
    }
    if (params.atualizarBandeira) {
      if (params.bandeiraVisualJson != null) {
        // Só persiste JSON: muitos projetos têm só a coluna `bandeira_visual` (sem colunas legadas).
        row['bandeira_visual'] = params.bandeiraVisualJson;
      } else {
        final ini = params.bandeiraIniciais?.trim() ?? '';
        row['bandeira_iniciais'] = ini.isEmpty ? null : (ini.length > 3 ? ini.substring(0, 3) : ini);
        row['bandeira_cor_primaria'] = params.bandeiraCorPrimaria == null || params.bandeiraCorPrimaria!.trim().isEmpty
            ? null
            : params.bandeiraCorPrimaria!.trim();
        row['bandeira_cor_secundaria'] = params.bandeiraCorSecundaria == null || params.bandeiraCorSecundaria!.trim().isEmpty
            ? null
            : params.bandeiraCorSecundaria!.trim();
        row['bandeira_simbolo'] = params.bandeiraSimbolo == null || params.bandeiraSimbolo!.trim().isEmpty
            ? null
            : params.bandeiraSimbolo!.trim();
        row['bandeira_emoji'] = params.bandeiraEmoji == null || params.bandeiraEmoji!.trim().isEmpty
            ? null
            : params.bandeiraEmoji!.trim();
      }
    }
    if (row.isEmpty) return;
    // Usa .update() sem .select() para evitar null quando o RLS permite UPDATE mas não SELECT.
    // Erro de banco ainda é propagado; ausência de linha no retorno não lança mais exceção.
    try {
      await client.from('apoiadores').update(row).eq('id', apoiadorId);
    } catch (e) {
      throw Exception('Erro ao salvar dados do apoiador: ${e.toString().replaceFirst('Exception: ', '')}');
    }
    ref.invalidate(apoiadoresListProvider);
    ref.invalidate(meuApoiadorProvider);
  };
});

/// Convidar apoiador por e-mail (cria usuário com role apoiador e preenche `apoiadores.profile_id`).
Future<String?> convidarApoiadorPorEmail({required String apoiadorId}) async {
  await supabase.auth.refreshSession();
  try {
    final body = <String, dynamic>{
      'apoiador_id': apoiadorId,
      'redirect_to': EnvConfig.webInviteRedirectTo,
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
      'redirect_to': EnvConfig.webInviteRedirectTo,
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

/// Candidato: remove o vínculo de login do apoiador (`profile_id` null + perfil inativo). Dados do cadastro permanecem.
Future<void> revogarAcessoApoiador(String apoiadorId) async {
  try {
    await supabase.auth.refreshSession();
    await supabase.rpc('candidato_revogar_acesso_apoiador', params: {'p_apoiador_id': apoiadorId});
  } catch (e) {
    throw Exception(messageFromException(e));
  }
}

/// Candidato: exclui o apoiador da campanha (soft delete), desativa o login e regista no histórico para restaurar.
Future<void> excluirApoiador(String apoiadorId) async {
  try {
    await supabase.auth.refreshSession();
    await supabase.rpc('candidato_excluir_apoiador', params: {'p_apoiador_id': apoiadorId});
  } catch (e) {
    throw Exception(messageFromException(e));
  }
}
