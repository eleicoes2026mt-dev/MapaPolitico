/// Implementação não-web (mobile/desktop): sem fragmento de redirect do browser.
Uri currentUriWithFragment() => Uri.base;

void replaceBrowserPath(String path) {}

void storePendingAuthErrorMessage(String message) {}

String? takePendingAuthErrorMessage() => null;
