import 'dart:io' show File, Platform;
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:whatsapp_share/whatsapp_share.dart';

/// Android: abre o WhatsApp já no chat do [phoneDigits] com a imagem (plugin `whatsapp_share`).
/// Outras plataformas: devolve `null` para usar a folha de partilha genérica.
Future<bool?> shareCartaoPngToWhatsappDirect({
  required Uint8List bytes,
  required String fileName,
  required String phoneDigits,
}) async {
  if (!Platform.isAndroid) return null;
  if (phoneDigits.isEmpty) return null;
  try {
    var pkg = Package.whatsapp;
    var installed = await WhatsappShare.isInstalled(package: pkg);
    if (installed != true) {
      pkg = Package.businessWhatsapp;
      installed = await WhatsappShare.isInstalled(package: pkg);
    }
    if (installed != true) return null;
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$fileName';
    await File(path).writeAsBytes(bytes);
    final ok = await WhatsappShare.shareFile(
      phone: phoneDigits,
      filePath: [path],
      package: pkg,
    );
    return ok;
  } catch (_) {
    return null;
  }
}
