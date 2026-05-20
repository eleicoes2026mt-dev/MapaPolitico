import 'dart:typed_data';

import 'invite_web_download_png_stub.dart'
    if (dart.library.html) 'invite_web_download_png_web.dart' as impl;

/// Na Web descarrega o PNG; nas outras plataformas é no-op.
void downloadInvitePngBlob(Uint8List bytes, String fileName) =>
    impl.downloadInvitePngBlob(bytes, fileName);
