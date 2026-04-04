import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../../models/partido.dart';
import '../../auth/providers/auth_provider.dart';

final partidosListProvider = FutureProvider<List<Partido>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final res = await supabase.from('partidos').select().order('sigla');
  final list = res as List;
  return list
      .map((e) => Partido.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});

/// Cria partido com upload da bandeira (bucket `bandeiras`).
Future<Partido> criarPartidoComBandeira({
  required String sigla,
  required String nome,
  required Uint8List bytes,
  required String fileExt,
}) async {
  final user = supabase.auth.currentUser;
  if (user == null) {
    throw Exception('Não autenticado');
  }
  final safeExt = fileExt.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
  final ext = safeExt.isEmpty ? 'jpg' : safeExt;
  final path = 'partidos/${user.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';
  await supabase.storage.from('bandeiras').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );
  final url = supabase.storage.from('bandeiras').getPublicUrl(path);
  final row = await supabase.from('partidos').insert({
    'sigla': sigla.trim().toUpperCase(),
    'nome': nome.trim(),
    'bandeira_url': url,
    'created_by': user.id,
  }).select().single();
  return Partido.fromJson(Map<String, dynamic>.from(row));
}
