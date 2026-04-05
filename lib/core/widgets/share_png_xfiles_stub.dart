import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Web: partilha a partir da memória.
Future<List<XFile>> pngToShareXFiles(Uint8List bytes, String fileName) async => [
      XFile.fromData(
        bytes,
        mimeType: 'image/png',
        name: fileName,
      ),
    ];
