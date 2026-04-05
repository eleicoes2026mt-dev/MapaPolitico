import 'dart:io' show Platform;

bool isDesktopOperatingSystem() =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;
