import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Partilha o PNG do cartão com legenda (texto + link).
/// No WhatsApp costuma aparecer como uma mensagem com imagem e legenda por baixo;
/// o comportamento exacto depende da versão do WhatsApp e da plataforma.
Future<void> shareInvitePngWithCaption({
  required Uint8List bytes,
  required String caption,
  required String fileName,
}) async {
  await Share.shareXFiles(
    [
      XFile.fromData(
        bytes,
        mimeType: 'image/png',
        name: fileName,
      ),
    ],
    text: caption,
  );
}
