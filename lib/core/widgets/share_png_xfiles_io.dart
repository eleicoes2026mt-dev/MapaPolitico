import 'dart:io' show File;
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Desktop / mobile: grava em ficheiro temporário — o WhatsApp e outras apps recebem melhor o anexo.
Future<List<XFile>> pngToShareXFiles(Uint8List bytes, String fileName) async {
  final dir = await getTemporaryDirectory();
  final path = '${dir.path}/$fileName';
  await File(path).writeAsBytes(bytes);
  return [
    XFile(
      path,
      mimeType: 'image/png',
      name: fileName,
    ),
  ];
}
