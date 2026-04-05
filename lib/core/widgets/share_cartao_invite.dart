import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import 'share_png_xfiles_stub.dart'
    if (dart.library.io) 'share_png_xfiles_io.dart' as share_png;

/// Partilha o PNG do cartão com legenda (texto + link).
/// No WhatsApp costuma aparecer como uma mensagem com imagem e legenda por baixo;
/// o comportamento exacto depende da versão do WhatsApp e da plataforma.
Future<void> shareInvitePngWithCaption({
  required Uint8List bytes,
  required String caption,
  required String fileName,
}) async {
  final files = await share_png.pngToShareXFiles(bytes, fileName);
  await Share.shareXFiles(files, text: caption);
}
