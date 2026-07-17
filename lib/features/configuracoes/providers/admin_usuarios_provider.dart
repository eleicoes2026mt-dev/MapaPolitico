import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_provider.dart';

/// Representa um usuário retornado pela RPC [admin_buscar_usuarios].
class AdminUsuario {
  const AdminUsuario({
    required this.uid,
    this.email,
    required this.nome,
    required this.papel,
    required this.ativo,
    required this.criadoEm,
  });

  final String uid;
  final String? email;
  final String nome;
  final String papel;
  final bool ativo;
  final DateTime criadoEm;

  factory AdminUsuario.fromJson(Map<String, dynamic> j) => AdminUsuario(
        uid: j['uid'] as String,
        email: j['email'] as String?,
        nome: j['nome'] as String? ?? '—',
        papel: j['papel'] as String? ?? 'sem_perfil',
        ativo: j['ativo'] as bool? ?? false,
        criadoEm: j['criado_em'] != null
            ? DateTime.parse(j['criado_em'].toString()).toLocal()
            : DateTime(2000),
      );

  String get papelLabel {
    switch (papel) {
      case 'candidato':
        return 'Candidato';
      case 'assessor':
        return 'Assessor';
      case 'apoiador':
        return 'Apoiador';
      case 'votante':
        return 'Amigo do Gilberto';
      case 'sem_perfil':
        return 'Sem perfil';
      default:
        return papel;
    }
  }
}

/// Busca usuários via RPC [admin_buscar_usuarios].
/// Parâmetro: string de pesquisa (vazio retorna todos, até 100).
final adminBuscarUsuariosProvider =
    Provider<Future<List<AdminUsuario>> Function(String pesquisa)>((ref) {
  return (String pesquisa) async {
    final res = await supabase
        .rpc('admin_buscar_usuarios', params: {'pesquisa': pesquisa});
    return (res as List)
        .map((e) => AdminUsuario.fromJson(e as Map<String, dynamic>))
        .toList();
  };
});

/// Exclui um usuário via RPC [admin_deletar_usuario].
/// A RPC remove da [auth.users] (cascade apaga perfil e dados filhos).
final adminDeletarUsuarioProvider =
    Provider<Future<void> Function(String uid)>((ref) {
  return (String uid) async {
    await supabase
        .rpc('admin_deletar_usuario', params: {'target_uid': uid});
  };
});
