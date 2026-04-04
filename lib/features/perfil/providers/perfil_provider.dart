import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';

typedef UpdateProfileParams = ({
  String? fullName,
  String? phone,
  String? cargo,
  String? partido,
  String? partidoId,
  DateTime? dataNascimento,
  String? avatarUrl,
  int? sqCandidatoTse2022,
});

final updateProfileProvider =
    Provider<Future<void> Function(UpdateProfileParams)>((ref) {
  final client = supabase;
  return (UpdateProfileParams params) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw Exception('Usuário não logado');
    final userId = user.id;
    final map = <String, dynamic>{
      'id': userId,
      'full_name': params.fullName ?? user.email ?? '',
      'email': user.email ?? '',
      'phone': params.phone,
      'cargo': params.cargo,
      'partido': params.partido,
      if (params.dataNascimento != null)
        'data_nascimento': params.dataNascimento!.toIso8601String().split('T').first,
      if (params.avatarUrl != null) 'avatar_url': params.avatarUrl,
      'sq_candidato_tse_2022': params.sqCandidatoTse2022,
    };

    final existing = await ref.read(profileProvider.future);
    final isCand = existing?.role == 'candidato';
    if (isCand) {
      map['partido_id'] = params.partidoId;
      map['numero_candidato'] = null;
    }
    // Nunca enviar `role` aqui: vinha do cache do Riverpod e podia ser "votante"
    // depois de promover a candidato na RPC, revertendo a base ao guardar o perfil.
    await client.from('profiles').upsert(map, onConflict: 'id');
    ref.invalidate(profileProvider);
  };
});
